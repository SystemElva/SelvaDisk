// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Extension = @import("Extension.zig");

pub const DiskPartitioner = struct {
    identifier: []const u8,

    fn_partition: (*fn () callconv(.c) void),
    fn_analyze: (*fn () callconv(.c) void),

    pub const FnPartitionDisk = (*fn (
        extension: *Extension,
    ) callconv(.c) void);
};

pub const FilesystemDriver = struct {
    identifier: []const u8,

    pub const FnCreateFilesystem = (*fn () callconv(.c) void);
};

pub const Postprocessor = struct {
    identifier: []const u8,
};
