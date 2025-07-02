// SPDX-License-Identifier: MPL-2.0

const std = @import("std");

pub const Partitioner = struct {
    scheme_name: []const u8,

    fn_partition: (*fn () callconv(.c) void),
    fn_analyze: (*fn () callconv(.c) void),
};

pub const FilesystemDriver = struct {
    //
};

pub const Postprocessor = struct {
    //
};
