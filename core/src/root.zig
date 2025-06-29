// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Core = @This();

allocator: std.mem.Allocator,

pub const CreationInfo = struct {};

pub fn init(
    creation_info: CreationInfo,
    allocator: std.mem.Allocator,
) !Core {
    _ = creation_info;
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(core: Core) void {
    _ = core;
}
