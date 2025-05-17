// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const api = @import("SelvaDiskApi.zig");

const Self = @This();

// Variables Region

// Types Region

pub const Error = error{
    NoInitializeFunction,
    InitializationFailed,
    SharedObjectLoaderFailure,
};

const FnInitialize = (*fn (
    driver_registry: *api.FilesystemDriver.Registry,
) callconv(.C) bool);

// Functions Region

pub fn deinit(self: *Self) void {
    self.shared_library.close();
}

pub fn load_all_plugins() !std.ArrayListUnmanaged(api.Addon) {
    const allocator = std.heap.smp_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);
    const string_allocator = arena.allocator();

    const folder_path = try std.fs.selfExeDirPathAlloc(string_allocator);

    const path_elements: [2][]const u8 = .{ folder_path, ".addons" };
    const addons_folder_path = try std.fs.path.join(string_allocator, &path_elements);

    const addons_folder = (try std.fs.openDirAbsolute(
        addons_folder_path,
        .{ .iterate = true },
    ));
    var folder_iterator = addons_folder.iterate();

    var addons: std.ArrayListUnmanaged(api.Addon) = try .initCapacity(allocator, 16);

    while (try folder_iterator.next()) |item| {
        if (item.kind != .file) {
            continue;
        }

        const addon_path_elements: [2][]const u8 = .{ addons_folder_path, item.name };
        const addon_path = try std.fs.path.join(string_allocator, &addon_path_elements);
        const addon_dynamic_library = try std.DynLib.open(addon_path);

        var addon: api.Addon = .{
            .shared_library = addon_dynamic_library,
            .vtable = .{},
            .supported_filesystems = .init(allocator),
        };
        try addon.initialize();

        try addons.append(allocator, addon);
    }
    arena.deinit();

    return addons;
}
