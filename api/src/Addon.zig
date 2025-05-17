// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
pub const Error = @import("root.zig").Error;

const Self = @This();

specifics_pointer: ?*anyopaque = null,
shared_library: std.DynLib,
vtable: VTable,

supported_filesystems: std.ArrayList([]u8),

// filesystem_drivers: ?std.ArrayList(FilesystemDriver) = null,

pub const FnInitialize = (*fn (
    addon: *Self,
) callconv(.C) bool);

pub const VTable = struct {
    destroy: ?(*fn (
        self: Self,
    ) void) = null,

    create_filesystem: ?(*fn (
        driver: Self,
        partition_json: std.json.Value,
        host_path: []u8,
    ) bool) = null,

    store_item: ?(*fn (
        driver: Self,
        destination_path: []u8,
        source_path: []u8,
    ) bool) = null,

    load_item: ?(*fn (
        driver: Self,
        destination_path: []u8,
        source_path: []u8,
    ) bool) = null,

    create_folder: ?(*fn (
        driver: Self,
        folder_path: []u8,
    ) bool) = null,

    remove_item: ?(*fn (
        driver: Self,
        item_path: []u8,
    ) bool) = null,

    list_items: ?(*fn (
        driver: Self,
        folder_path: []u8,
    ) bool) = null,
};

pub fn initialize(self: *Self) !void {
    const unchecked_init_function = self.shared_library.lookup(
        FnInitialize,
        "initialize",
    );
    if (unchecked_init_function == null) {
        return Error.NoInitializationFunction;
    }
    const checked_init = unchecked_init_function.?;
    const status = checked_init(self);
    if (!status) {
        return Error.InitializationFailed;
    }
}

pub fn createFilesystem(
    self: Self,
    partition_json: std.json.Value,
    host_path: []u8,
) bool {
    if (self.vtable.create_filesystem == null) {
        return false;
    }
    return self.vtable.create_filesystem.?(
        self,
        partition_json,
        host_path,
    );
}

pub fn storeItem(
    self: Self,
    destination_path: []u8,
    source_path: []u8,
) bool {
    if (self.vtable.store_item == null) {
        return false;
    }
    return self.vtable.store_item.?(
        self,
        destination_path,
        source_path,
    );
}

pub fn loadItem(
    self: Self,
    destination_path: []u8,
    source_path: []u8,
) bool {
    if (self.vtable.load_item == null) {
        return false;
    }
    return self.vtable.load_item.?(
        self,
        destination_path,
        source_path,
    );
}

pub fn createFolder(
    self: Self,
    folder_path: []u8,
) bool {
    if (self.vtable.create_folder == null) {
        return false;
    }
    return self.vtable.create_folder.?(
        self,
        folder_path,
    );
}

pub fn removeItem(
    self: Self,
    item_path: []u8,
) bool {
    if (self.vtable.remove_item == null) {
        return false;
    }
    return self.vtable.remove_item.?(
        self,
        item_path,
    );
}

pub fn listItems(
    self: Self,
    folder_path: []u8,
) bool {
    if (self.vtable.listItems == null) {
        return false;
    }
    return self.vtable.listItems.?(
        self,
        folder_path,
    );
}
