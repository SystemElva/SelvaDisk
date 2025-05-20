// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
pub const Addon = @import("Addon.zig");

const Self = @This();

general_purpose_allocator: std.mem.Allocator,

partitioning_scheme_handlers: std.ArrayList(*Addon),
filesystem_handlers: std.ArrayList(*Addon),
addon_list: std.ArrayList(Addon),

pub const Error = error{
    FilesystemDriverNotFound,
    InvalidFilesystemJson,
    NoInitializationFunction,
    UnsupportedFilesystem,
    InitializationFailure,
    FilesystemHandlerFailure,
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
        const partitioning_schemes = std.ArrayList(Addon.FnPartitionDisk).init(general_purpose_allocator);
        try addon_list.append(.{
            .label = "",
            .shared_library = addon_dynamic_library,
            .allocator = general_purpose_allocator,
            .filesystems = filesystems,
            .disk_partitioners = partitioning_schemes,
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

pub fn createFilesystem(
    self: *Self,
    filesystem_json: ?std.json.Value,
) Error!void {
    // Find the addon that supports this filesystem

    _ = filesystem_json;

    // if (filesystem_json.? != .object) {
    //     return Error.InvalidFilesystemJson;
    // }
    const filesystem_name: ?[]const u8 = "fat12"; // filesystem_json.?.object.get("filesystem");
    if (filesystem_name == null) {
        return Error.UnsupportedFilesystem;
    }

    var unchecked_addon: ?*Addon = null;
    var addon_index: usize = 0;
    while (addon_index < self.filesystem_handlers.items.len) {
        if (self.addon_list.items[addon_index].supportsFilesystem(filesystem_name.?)) {
            unchecked_addon = &self.addon_list.items[addon_index];
            break;
        }
        addon_index += 1;
    }

    if (unchecked_addon == null) {
        return Error.FilesystemDriverNotFound;
    }
    var addon = unchecked_addon.?;
    const filesystem = addon.searchFilesystem(filesystem_name.?);
    if (filesystem == null) {
        return Error.UnsupportedFilesystem; // @todo: Create another error for this
    }

    var empty_value: std.json.Value = .{ .bool = true };

    if (!filesystem.?.create(addon, &empty_value)) {
        return Error.FilesystemHandlerFailure;
    }
}

pub fn setupAllAddons(self: *Self) !void {
    var addon_index: usize = 0;
    while (addon_index < self.addon_list.items.len) {
        var addon = &self.addon_list.items[addon_index];
        try addon.setup(self);
        addon_index += 1;
    }
}
