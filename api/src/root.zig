// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
pub const Addon = @import("Addon.zig");
pub const Description = @import("Description.zig");

const Self = @This();

general_purpose_allocator: std.mem.Allocator,

partitioning_scheme_handlers: std.ArrayList(*Addon),
filesystem_handlers: std.ArrayList(*Addon),
addon_list: std.ArrayList(Addon),

pub const Error = error{
    InvalidDiskJson,
    NoPartitioningSchemeGiven,
    UnsupportedPartitioningScheme,
    PartitioningHandlerFailure,

    InvalidFilesystemJson,
    FilesystemDriverNotFound,
    UnsupportedFilesystem,
    FilesystemHandlerFailure,

    NoInitializationFunction,
    InitializationFailure,
};

// Initialization functions (functions for addons to use)

pub export fn registerFilesystemCreator(
    self: *Self,
    addon: *Addon,
    filesystem: *const Addon.Filesystem,
) callconv(.C) bool {
    self.filesystem_handlers.append(
        addon,
    ) catch {
        return false;
    };
    addon.filesystems.append(filesystem.*) catch {
        return false;
    };
    return true;
}

pub export fn registerPartitioningScheme(
    self: *Self,
    addon: *Addon,
    scheme: *const Addon.PartitioningScheme,
) callconv(.C) bool {
    self.partitioning_scheme_handlers.append(addon) catch {
        return false;
    };
    addon.partitioning_schemes.append(scheme.*) catch {
        return false;
    };
    return true;
}

// Exposure functions (functions for the core to use)

pub fn init(
    addon_folder_path: []const u8,
    general_purpose_allocator: std.mem.Allocator,
) !Self {
    var arena = std.heap.ArenaAllocator.init(general_purpose_allocator);
    defer arena.deinit();
    const path_allocator = arena.allocator();

    const addons_folder = (try std.fs.openDirAbsolute(
        addon_folder_path,
        .{ .iterate = true },
    ));
    var folder_iterator = addons_folder.iterate();

    var addon_list = try std.ArrayList(
        Addon,
    ).initCapacity(general_purpose_allocator, 16);

    while (try folder_iterator.next()) |item| {
        if (item.kind != .file) {
            continue;
        }

        const addon_path_elements: [2][]const u8 = .{ addon_folder_path, item.name };
        const addon_path = try std.fs.path.join(path_allocator, &addon_path_elements);
        const addon_dynamic_library = try std.DynLib.open(addon_path);

        const filesystems = std.ArrayList(Addon.Filesystem).init(general_purpose_allocator);
        const partitioning_schemes = std.ArrayList(Addon.PartitioningScheme).init(general_purpose_allocator);
        try addon_list.append(.{
            .label = "",
            .shared_library = addon_dynamic_library,
            .allocator = general_purpose_allocator,
            .filesystems = filesystems,
            .partitioning_schemes = partitioning_schemes,
        });
    }
    return .{
        .general_purpose_allocator = general_purpose_allocator,
        .addon_list = addon_list,
        .partitioning_scheme_handlers = .init(general_purpose_allocator),
        .filesystem_handlers = .init(general_purpose_allocator),
    };
}

pub fn deinit(
    self: *Self,
) void {
    self.filesystem_handlers.deinit();
    self.partitioning_scheme_handlers.deinit();

    for (self.addon_list.items) |*addon| {
        addon.deinit();
    }
    self.addon_list.deinit();
}

pub fn setupAllAddons(self: *Self) !void {
    var addon_index: usize = 0;
    while (addon_index < self.addon_list.items.len) {
        var addon = &self.addon_list.items[addon_index];
        try addon.setup(self);
        addon_index += 1;
    }
}

pub fn partitionDisk(
    self: *Self,
    description: Description,
    output_path: []const u8,
) !void {

    // Get name of wanted partitioning scheme

    if (description.source_json != .object) {
        return Error.InvalidDiskJson;
    }

    const unchecked_partitioning_scheme_name = description.source_json.object.get("partitioning");
    if (unchecked_partitioning_scheme_name == null) {
        return Error.NoPartitioningSchemeGiven;
    }
    if (unchecked_partitioning_scheme_name.? != .string) {
        return Error.InvalidDiskJson;
    }
    const partitioning_scheme_name = unchecked_partitioning_scheme_name.?.string;

    // Find partitioning scheme structure

    var partitioning_scheme: ?*Addon.PartitioningScheme = null;
    var supporting_addon: ?*Addon = null;

    for (self.addon_list.items) |*addon| {
        const found_partitioning_scheme = addon.searchPartitioningScheme(partitioning_scheme_name);
        if (found_partitioning_scheme != null) {
            partitioning_scheme = found_partitioning_scheme;
            supporting_addon = addon;
            break;
        }
    }
    if (partitioning_scheme == null) {
        return Error.UnsupportedPartitioningScheme;
    }
    if (!partitioning_scheme.?.partition_disk(
        supporting_addon.?,
        &description,
        &output_path,
    )) {
        return Error.PartitioningHandlerFailure;
    }
}

pub fn createFilesystem(
    self: *Self,
    description: Description,
    filesystem_json: ?std.json.Value,
) Error!void {
    // Find the addon that supports this filesystem

    _ = filesystem_json;

    // @otdo: Don't hardcode for FAT12

    const filesystem_name: ?[]const u8 = "fat12"; // filesystem_json.?.object.get("filesystem");
    if (filesystem_name == null) {
        return Error.UnsupportedFilesystem;
    }

    var unchecked_addon: ?*Addon = null;
    var addon_index: usize = 0;
    while (addon_index < self.filesystem_handlers.items.len) {
        if (self.filesystem_handlers.items[addon_index].*.supportsFilesystem(filesystem_name.?)) {
            unchecked_addon = self.filesystem_handlers.items[addon_index];
            break;
        }
        addon_index += 1;
    }

    if (unchecked_addon == null) {
        return Error.UnsupportedFilesystem;
    }
    var addon = unchecked_addon.?;
    const filesystem = addon.searchFilesystem(filesystem_name.?);
    if (filesystem == null) {
        return Error.UnsupportedFilesystem;
    }

    // @todo: The empty value was only for testing purposes

    var empty_value: std.json.Value = .{ .bool = true };

    if (!filesystem.?.create(
        addon,
        &description,
        &empty_value,
    )) {
        return Error.FilesystemHandlerFailure;
    }
}
