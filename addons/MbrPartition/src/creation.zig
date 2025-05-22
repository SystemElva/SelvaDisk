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

    std.log.warn("volume size strings aren't implemented yet. using default: 3.5\" HD floppy size (1.44MiB)", .{});
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
        std.log.warn("volume size not given. using default: 3.5\" HD floppy size (1.44MiB)", .{});
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
            "no sector size given. using default: 512 bytes per sector",
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
            "sector size strings arent't implemented yet. using default: 512 bytes per sector",
            .{},
        );
    }
    return .{
        .bytes_per_sector = sector_size,
        .num_sectors = volume_size,
    };
}

fn parse_partition_entry(partition_json: *std.json.Value) !Partition {
    if (partition_json.* != .object) {
        return CreationError.InvalidPartitionsJsonType; // @todo: Seperate error for this
    }

    const map = partition_json.object;
    const nullable_start = map.get("start");
    if (nullable_start == null) {
        std.log.err("partition-start is not optional but wasn't found", .{});
        return CreationError.NoPartitionStartGiven;
    }
    if (nullable_start.? != .integer) {
        std.log.err("partition-start must be an integer", .{});
        return CreationError.InvalidPartitionStartGiven;
    }

    const nullable_length = map.get("length");
    if (nullable_length == null) {
        std.log.err("partition-length is not optional but wasn't found", .{});
        return CreationError.NoPartitionLengthGiven;
    }
    if (nullable_length.? != .integer) {
        std.log.err("partition-length must be an integer", .{});
        return CreationError.InvalidPartitionLengthGiven;
    }

    // Get the content type and set it to zeroes if none was given.

    const nullable_content_string = map.get("content");
    var content_string: []const u8 = "zeroes";
    if (nullable_content_string != null) {
        if (nullable_content_string.? != .string) {
            return CreationError.InvalidContentIdentifier;
        }
        content_string = nullable_content_string.?.string;
    }

    const nullable_type_identifier = map.get("type");
    var type_identifier: u8 = 0;
    if (nullable_type_identifier != null) {
        if (nullable_type_identifier.? != .integer) {
            std.log.info("partition-type must be an integer", .{});
            return CreationError.InvalidPartitionTypeJsonType;
        } else {
            const unchecked_type_identifier = nullable_type_identifier.?.integer;
            if (unchecked_type_identifier < 0) {
                std.log.err("partition-type must be a positive integer", .{});
                return CreationError.InvalidPartitionTypeNumber;
            }
            if (unchecked_type_identifier > 255) {
                std.log.err("partition-type must be below 255", .{});
                return CreationError.InvalidPartitionTypeNumber;
            }
            type_identifier = @intCast(unchecked_type_identifier);
        }
    }

    return .{
        .type_identifier = type_identifier,
        .start = @intCast(nullable_start.?.integer),
        .length = @intCast(nullable_length.?.integer),
        .content = try .fromString(content_string),
        .json_object = &partition_json.object,
    };
}

fn parse_partition_list(
    allocator: std.mem.Allocator,
    description: *const Api.Description,
) ![]Partition {
    const json: std.json.Value = description.source_json;
    const nullable_json_partitions = json.object.get("partitions");

    if (nullable_json_partitions == null) {
        std.log.err("root-item 'partitions' is not optional", .{});
        return CreationError.NoPartitionsDefined;
    }
    if (nullable_json_partitions.? != .array) {
        std.log.err("root-item 'partitions' must be an array", .{});
        return CreationError.InvalidPartitionsJsonType;
    }
    const partitions_json = nullable_json_partitions.?.array;

    var partitions: []Partition = try allocator.alloc(
        Partition,
        partitions_json.items.len,
    );

    var partition_index: usize = 0;
    while (partition_index < partitions_json.items.len) {
        partitions[partition_index] = try parse_partition_entry(&partitions_json.items[partition_index]);
        partition_index += 1;
    }
    return partitions;
}

fn get_disk_info(
    allocator: std.mem.Allocator,
    description: *const Api.Description,
) !DiskInfo {
    const json: std.json.Value = description.source_json;

    if (json != .object) {
        return CreationError.RootNotAnObject;
    }

    const nullable_base_folder_path = std.fs.path.dirname(description.source_path);
    if (nullable_base_folder_path == null) {
        return CreationError.BaseFolderOpenFailure;
    }
    const base_folder = std.fs.openDirAbsolute(
        nullable_base_folder_path.?,
        .{},
    ) catch {
        std.log.err(
            "failed opening mbr disk definition base folder at '{s}'",
            .{nullable_base_folder_path.?},
        );
        return CreationError.BaseFolderOpenFailure;
    };

    const bootcode = get_bootcode(
        description,
        base_folder,
    ) catch |bootcode_err| {
        return bootcode_err;
    };
    const disk_geometry = parse_disk_geometry(description) catch |disk_geometry_error| {
        return disk_geometry_error;
    };

    return DiskInfo{
        .geometry = disk_geometry,
        .partitions = parse_partition_list(
            allocator,
            description,
        ) catch |partition_list_error| {
            return partition_list_error;
        },
        .bootcode = bootcode,
    };
}

fn write_partition_entry(
    partition: Partition,
    bytes: []u8,
) void {
    bytes[0] = 0x80;
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

fn write_bootsector(
    disk_info: *const DiskInfo,
    output_file: *std.fs.File,
) !void {
    var bytes = [1]u8{0} ** 512;
    @memcpy(bytes[0..446], &disk_info.bootcode);
    bytes[510] = 0x55;
    bytes[511] = 0xaa;

    var partition_index: usize = 0;
    while (partition_index < disk_info.partitions.len) {
        const entry_start = 446 + (partition_index * 16);
        write_partition_entry(
            disk_info.partitions[partition_index],
            bytes[entry_start .. entry_start + 16],
        );
        partition_index += 1;
    }
    _ = try output_file.write(&bytes);
}

fn write_file_partition(
    disk_info: *const DiskInfo,
    description: *const Api.Description,
    partition: *const Partition,
    output_file: *std.fs.File,
) !void {
    const nullable_file_path = partition.json_object.get("file");
    if (nullable_file_path == null) {
        std.log.err("no partition file path given", .{});
        return CreationError.InvalidContentFile;
    }
    if (nullable_file_path.? != .string) {
        std.log.err("partition file path not a string", .{});
        return CreationError.InvalidContentFile;
    }

    const file_path = nullable_file_path.?.string;
    const source_folder_path = std.fs.path.dirname(description.source_path);
    if (source_folder_path == null) {
        return CreationError.InvalidContentFile;
    }

    var source_folder = std.fs.openDirAbsolute(
        source_folder_path.?,
        .{},
    ) catch {
        std.log.err("failed opening source folder", .{});
        return CreationError.InvalidContentFile;
    };
    defer source_folder.close();

    const file = source_folder.openFile(
        file_path,
        .{ .mode = .read_only },
    ) catch {
        std.log.err("failed opening source file", .{});
        return CreationError.InvalidContentFile;
    };
    defer file.close();

    _ = try file.copyRange(
        0,
        output_file.*,
        partition.start * disk_info.geometry.bytes_per_sector,
        partition.length * disk_info.geometry.bytes_per_sector,
    );
}

fn fill_output_file(
    disk_info: *const DiskInfo,
    description: *const Api.Description,
    output_file: *std.fs.File,
) !void {
    _ = description;

    const zero_sector = try std.heap.smp_allocator.alloc(
        u8,
        disk_info.geometry.bytes_per_sector,
    );
    @memset(zero_sector, 0);

    defer std.heap.smp_allocator.free(zero_sector);

    var sector_index: usize = 0;
    while (sector_index < disk_info.geometry.num_sectors) {
        _ = try output_file.write(zero_sector);
        sector_index += 1;
    }
}

fn write_disk(
    disk_info: *const DiskInfo,
    description: *const Api.Description,
    output_file: *std.fs.File,
) !void {
    try fill_output_file(
        disk_info,
        description,
        output_file,
    );
    try output_file.seekTo(0);

    try write_bootsector(
        disk_info,
        output_file,
    );
    for (disk_info.partitions) |partition| {
        switch (partition.content) {
            .zeroes => {},
            .file => {
                try write_file_partition(
                    disk_info,
                    description,
                    &partition,
                    output_file,
                );
            },
            .filesystem => {
                std.log.err("filesystem creation isn't implemented yet", .{});
            },
        }
    }
}

pub export fn create_mbr_disk(
    addon: *Api.Addon,
    description: *const Api.Description,
    output_path: *const []const u8,
) callconv(.C) bool {
    _ = addon;

    const disk_info = get_disk_info(
        std.heap.smp_allocator,
        description,
    ) catch {
        return false;
    };

    const output_folder_path = std.fs.path.dirname(output_path.*);
    if (output_folder_path == null) {
        std.log.err("failed getting folder to store output-file in", .{});
        return false;
    }

    var output_file = std.fs.createFileAbsolute(output_path.*, .{ .truncate = true }) catch {
        std.log.err("failed creating output-file: {s}", .{output_path});
        return false;
    };

    write_disk(
        &disk_info,
        description,
        &output_file,
    ) catch {
        return false;
    };

    return true;
}

const DiskGeometry = struct {
    bytes_per_sector: usize = 512,
    num_sectors: usize = 2880,
};

const Partition = struct {
    type_identifier: u8 = 1,
    start: usize = 0,
    length: usize = 0,
    content: Content = .zeroes,

    json_object: *std.json.ObjectMap,

    const Content = enum {
        zeroes,
        file,
        filesystem,

        fn fromString(string: []const u8) !Content {
            if (std.mem.eql(u8, string, "zeroes")) {
                return .zeroes;
            }
            if (std.mem.eql(u8, string, "file")) {
                return .file;
            }
            if (std.mem.eql(u8, string, "filesystem")) {
                return .filesystem;
            }
            return CreationError.InvalidContentIdentifier;
        }

        fn toString(content: Content) []const u8 {
            return switch (content) {
                .zeroes => "zeroes",
                .file => "file",
                .filesystem => "filesystem",
            };
        }
    };
};

const DiskInfo = struct {
    geometry: DiskGeometry,
    partitions: []Partition,
    bootcode: [446]u8,
};

const CreationError = error{
    InvalidBootCodeJsonType,
    BootCodeFileNotFound,
    BootCodeAccessDenied,
    BootCodeReadError,
    GenericBootCodeFileAccessError,

    InvalidContentFile,

    RootNotAnObject,
    BaseFolderOpenFailure,

    InvalidPartitionTypeJsonType,
    InvalidPartitionTypeNumber,

    InvalidPartitionsJsonType,
    NoPartitionsDefined,
    NoPartitionStartGiven,
    NoPartitionLengthGiven,
    InvalidPartitionStartGiven,
    InvalidPartitionLengthGiven,

    InvalidContentIdentifier,

    InvalidVolumeSizeJsonType,
    VolumeSizeTooSmall,
    SectorSizeTooLarge,
    SectorSizeTooSmall,
};
