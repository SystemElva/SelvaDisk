// SPDX-License-Identifier: MPL-2.0

const std = @import("std");

pub const Error = error{
    FilesystemDriverNotFound,
};

pub const FilesystemDriver = struct {
    filesystem_name: []u8,
    vtable: VTable,

    const VTable = struct {
        create_fs: ?(*fn (
            driver: FilesystemDriver,
            partition_json: std.json.Value,
            host_path: []u8,
        ) bool) = null,

        store_item: ?(*fn (
            driver: FilesystemDriver,
            destination_path: []u8,
            source_path: []u8,
        ) bool) = null,

        load_item: ?(*fn (
            driver: FilesystemDriver,
            destination_path: []u8,
            source_path: []u8,
        ) bool) = null,

        create_folder: ?(*fn (
            driver: FilesystemDriver,
            folder_path: []u8,
        ) bool) = null,

        remove_item: ?(*fn (
            driver: FilesystemDriver,
            item_path: []u8,
        ) bool) = null,

        list_items: ?(*fn (
            driver: FilesystemDriver,
            folder_path: []u8,
        ) bool) = null,
    };

    pub const Registry = struct {
        filesystems: std.StringHashMap(FilesystemDriver),

        pub fn init(allocator: std.mem.Allocator) Registry {
            return .{
                .filesystems = .init(allocator),
            };
        }
    };

    pub fn new(
        registry: Registry,
        name: []u8,
        allocator: std.mem.Allocator,
    ) *FilesystemDriver {
        const filesystem_driver: FilesystemDriver = allocator.dupe(
            FilesystemDriver,
            .{
                .filesystem_name = allocator.dupe(name),
            },
        );
        registry.filesystems.put(
            name,
            filesystem_driver,
        );
        return filesystem_driver;
    }

    pub fn search(registry: *Registry, name: []u8) !FilesystemDriver {
        const filesystem = registry.filesystems.get(name);
        if (filesystem == null) {
            return Error.FilesystemDriverNotFound;
        }
        return filesystem.?;
    }

    pub fn createFs(
        self: FilesystemDriver,
        partition_json: std.json.Value,
        host_path: []u8,
    ) bool {
        if (self.vtable.create_fs == null) {
            return false;
        }
        return self.vtable.create_fs.?(
            self,
            partition_json,
            host_path,
        );
    }

    pub fn storeItem(
        self: FilesystemDriver,
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
        self: FilesystemDriver,
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
        self: FilesystemDriver,
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
        self: FilesystemDriver,
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
        self: FilesystemDriver,
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
};

// Partition management - related actions
pub const part = struct {
    // @todo: Design partition management API
};
