// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Api = @import("root.zig");
pub const Error = @import("root.zig").Error;

const Self = @This();

label: []const u8,

specifics_pointer: ?*anyopaque = null,
allocator: std.mem.Allocator,
shared_library: std.DynLib,

filesystems: std.ArrayList(Filesystem),
partitioning_schemes: std.ArrayList(PartitioningScheme),

// Function Pointers

pub const FnInitialize = (*const fn (
    addon: *Self,
    api: *Api,
) callconv(.C) bool);

pub const Filesystem = struct {
    label: *const []const u8,
    create: FnCreate,

    pub const FnCreate = (*const fn (
        self: *Self,
        filesystem_json: *std.json.Value,
    ) callconv(.C) bool);
};

pub const PartitioningScheme = struct {
    label: *const []const u8,
    partition_disk: FnPartitionDisk,

    pub const FnPartitionDisk = (*const fn (
        self: *Self,
        disk_json: *std.json.Value,
    ) callconv(.C) bool);
};

pub fn deinit(
    self: *Self,
) void {
    self.partitioning_schemes.deinit();
    self.filesystems.deinit();
    self.shared_library.close();
}

pub fn setup(
    self: *Self,
    api: *Api,
) !void {
    const unchecked_init_function = self.shared_library.lookup(
        FnInitialize,
        "initialize",
    );
    if (unchecked_init_function == null) {
        return Error.NoInitializationFunction;
    }
    const checked_init = unchecked_init_function.?;
    const status = checked_init(self, api);
    if (!status) {
        return Error.InitializationFailure;
    }
}

pub fn searchFilesystem(self: *Self, label: []const u8) ?*Filesystem {
    var filesystem_index: usize = 0;
    while (filesystem_index < self.filesystems.items.len) {
        if (std.mem.eql(
            u8,
            self.filesystems.items[filesystem_index].label.*,
            label,
        )) {
            return &self.filesystems.items[filesystem_index];
        }
        filesystem_index += 1;
    }
    return null;
}

pub fn supportsFilesystem(self: *Self, label: []const u8) bool {
    var filesystem_index: usize = 0;
    while (filesystem_index < self.filesystems.items.len) {
        if (std.mem.eql(
            u8,
            self.filesystems.items[filesystem_index].label.*,
            label,
        )) {
            return true;
        }
        filesystem_index += 1;
    }
    return false;
}

pub fn searchPartitioningScheme(
    self: *Self,
    label: []const u8,
) ?*PartitioningScheme {
    var partitioning_scheme_index: usize = 0;
    while (partitioning_scheme_index < self.partitioning_schemes.items.len) {
        const partition_scheme = &self.partitioning_schemes.items[partitioning_scheme_index];
        if (std.mem.eql(
            u8,
            partition_scheme.label.*,
            label,
        )) {
            return partition_scheme;
        }
        partitioning_scheme_index += 1;
    }
    return null;
}
