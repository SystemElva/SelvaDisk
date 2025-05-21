// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Api = @import("SelvaDiskApi.zig");

fn get_bootcode(
    description: *const Api.Description,
    base_folder: std.fs.Dir,
) ![446]u8 {
    const nullable_bootcode_path = description.source_json.object.get("bootcode");
    if (nullable_bootcode_path == null) {
        // If no boot-code was specified, fill the boot-code section
        // with 0x90, the no-operation (NOP) opcode of x86.

        return .{0x90} ** 446;
    }
    if (nullable_bootcode_path.? != .string) {
        std.log.warn("invalid type of json-item 'bootcode', must be string", .{});
        return CreationError.InvalidBootCodeJsonType;
    }
    const bootcode_path = nullable_bootcode_path.?.string;

    const bootcode_file = base_folder.openFile(
        bootcode_path,
        .{ .mode = .read_only },
    ) catch |err| {
        var error_equivalent = CreationError.GenericBootCodeFileAccessError;
        if (err == error.AccessDenied) {
            error_equivalent = CreationError.BootCodeAccessDenied;
        }
        if (err == error.FileNotFound) {
            error_equivalent = CreationError.BootCodeFileNotFound;
        }

        std.log.warn(
            "failed gathering bootcode at '{s}': {s}'",
            .{ bootcode_path, @errorName(error_equivalent) },
        );

        return error_equivalent;
    };

    // @todo: This only reads the first 446 bytes of the file.
    //        One might consider to warn the user if the file is longer
    //        than that, maybe even if it is shorter.
    //        The best behavior in such a situation is still up for debate.

    var bootcode: [446]u8 = .{@as(u8, 0)} ** 446;
    _ = bootcode_file.read(&bootcode) catch {
        return CreationError.BootCodeReadError;
    };

    return bootcode;
}

fn parse_disk_size_string(description: *const Api.Description) !DiskGeometry {
    _ = description;

    std.log.warn("volume size strings aren't implemented yet. Using default: 3.5\" HD floppy size (1.44MiB)", .{});
    return .{
        .bytes_per_sector = 512,
        .num_sectors = 2880,
    };
}

fn parse_disk_geometry(
    description: *const Api.Description,
) !DiskGeometry {
    // @todo: Warn when returning an error.

    const nullable_volume_size = description.source_json.object.get("volume_size");
    if (nullable_volume_size == null) {
        std.log.warn("volume size not given. Using default: 3.5\" HD floppy size (1.44MiB)", .{});
        return .{
            .bytes_per_sector = 512,
            .num_sectors = 2880,
        };
    }
    if (nullable_volume_size.? == .string) {
        return parse_disk_size_string(description);
    }

    if (nullable_volume_size.? != .integer) {
        return CreationError.InvalidVolumeSizeJsonType;
    }
    const raw_volume_size = nullable_volume_size.?.integer;
    if (raw_volume_size <= 0) {
        return CreationError.VolumeSizeTooSmall;
    }

    const volume_size: usize = @truncate(@abs(raw_volume_size));

    // Parse volume size with explicit cluster size definition

    const nullable_sector_size = description.source_json.object.get("cluster_size");
    if (nullable_sector_size == null) {
        std.log.info(
            "no sector size given. Using default: 512 bytes per sector",
            .{},
        );
        return .{
            .num_sectors = volume_size,
        };
    }
    // @todo: Support giving a cluster size as 4K, 0.5K, 1M, etc..

    var sector_size: usize = 512;
    if (nullable_sector_size.? == .integer) {
        const raw_sector_size = nullable_sector_size.?.integer;
        if (raw_sector_size <= 0) {
            std.log.err(
                "sector size must be at least 1, with 512 being recommended for compatibility. Got: {d}",
                .{raw_sector_size},
            );
            return CreationError.SectorSizeTooSmall;
        }
        if (raw_sector_size > (4 * 1024 * 1024)) {
            // @todo: It should be possible to configure the maximum sector size in a
            //        JSON-based central system-wide or per-user configuration.

            std.log.err(
                "refusing to create sectors larger than 419304 bytes (4 MiB), got: {d}",
                .{raw_sector_size},
            );
            return CreationError.SectorSizeTooLarge;
        }
        if (!std.math.isPowerOfTwo(raw_sector_size)) {
            std.log.warn(
                "sector size is not a power of two (got: {d}). This WILL negatively affect compatibility",
                .{raw_sector_size},
            );
        }

        sector_size = @truncate(@abs(raw_sector_size));
    } else {
        std.log.warn(
            "sector size strings arent't implemented yet. Using default: 512 bytes per sector",
            .{},
        );
    }
    return .{
        .bytes_per_sector = sector_size,
        .num_sectors = volume_size,
    };
}

fn parse_partition_list(description: *const Api.Description) ![4]Partition {
    _ = description;
}

fn insert_partition_entry(partition: Partition, bytes: *[]u8) void {
    bytes[4] = partition.type_identifier;

    bytes[8] = @intCast(partition.start & 0xff);
    bytes[9] = @intCast((partition.start >> 8) & 0xff);
    bytes[10] = @intCast((partition.start >> 16) & 0xff);
    bytes[11] = @intCast(partition.start >> 24);

    bytes[12] = @intCast(partition.length & 0xff);
    bytes[13] = @intCast((partition.length >> 8) & 0xff);
    bytes[14] = @intCast((partition.length >> 16) & 0xff);
    bytes[15] = @intCast(partition.length >> 24);
}

fn write_bootsector(disk_info: *const DiskInfo, output: *std.fs.File) !void {
    var bytes = [1]u8{0} ** 512;
    @memcpy(bytes[0..446], &disk_info.bootcode);
    bytes[510] = 0x55;
    bytes[511] = 0xaa;

    _ = try output.write(&bytes);
}

pub export fn create_mbr_disk(
    addon: *Api.Addon,
    description: *const Api.Description,
    output_path: *const []const u8,
) callconv(.C) bool {
    _ = addon;

    const json: std.json.Value = description.source_json;

    if (json != .object) {
        return false;
    }

    const nullable_base_folder_path = std.fs.path.dirname(description.source_path);
    if (nullable_base_folder_path == null) {
        return false;
    }
    const base_folder = std.fs.openDirAbsolute(
        nullable_base_folder_path.?,
        .{},
    ) catch {
        std.log.err(
            "failed opening mbr disk definition base folder at '{s}'",
            .{nullable_base_folder_path.?},
        );
        return false;
    };

    const bootcode = get_bootcode(description, base_folder) catch {
        return false;
    };
    const disk_geometry = parse_disk_geometry(description) catch {
        return false;
    };

    const disk_info = DiskInfo{
        .bootcode = bootcode,
        .geometry = disk_geometry,
    };

    const output_folder_path = std.fs.path.dirname(output_path.*);
    if (output_folder_path == null) {
        std.log.err("failed getting folder to store output-file in", .{});
        return false;
    }

    var output_file = std.fs.openFileAbsolute(
        output_path.*,
        .{ .mode = .write_only },
    ) catch file_creation: {
        break :file_creation std.fs.createFileAbsolute(output_path.*, .{}) catch {
            std.log.err("failed creating output-file: {s}", .{output_path});
            return false;
        };
    };

    write_bootsector(&disk_info, &output_file) catch {
        std.log.err("failed writing bootsector", .{});
        return false;
    };

    return true;
}

const DiskGeometry = struct {
    bytes_per_sector: usize = 512,
    num_sectors: usize = 2880,
};

const Partition = struct {
    type_identifier: u8,
    start: usize,
    length: usize,
    content: Content,

    const Content = enum {
        file,
        filesystem,
    };
};

const DiskInfo = struct {
    geometry: DiskGeometry,
    bootcode: [446]u8,
};

const CreationError = error{
    InvalidBootCodeJsonType,
    BootCodeFileNotFound,
    BootCodeAccessDenied,
    BootCodeReadError,
    GenericBootCodeFileAccessError,
    InvalidVolumeSizeJsonType,
    VolumeSizeTooSmall,
    SectorSizeTooLarge,
    SectorSizeTooSmall,
};
