// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Api = @import("SelvaDiskApi.zig");

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

fn parse_disk_size_string(description: *const Api.Description) !usize {
    _ = description;

    std.log.warn("volume size strings aren't implemented yet. Using default: 3.5\" HD floppy size (1.44MiB)", .{});
    return 2880 * 512;
}

fn get_disk_size(
    description: *const Api.Description,
) !usize {
    // @todo: Warn when returning an error.

    const nullable_volume_size = description.source_json.object.get("volume_size");
    if (nullable_volume_size == null) {
        std.log.warn("volume size not given. Using default: 3.5\" HD floppy size (1.44MiB)", .{});
        return 2880 * 512;
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
        return volume_size * 512;
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
    return volume_size * sector_size;
}

pub export fn create_mbr_disk(
    addon: *Api.Addon,
    description: *const Api.Description,
    output_path: *const []const u8,
) callconv(.C) bool {
    _ = addon;
    _ = output_path;

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
    const disk_size = get_disk_size(description) catch {
        return false;
    };

    _ = bootcode;
    std.log.info("creating volume with {d} bytes", .{disk_size});

    return true;
}
