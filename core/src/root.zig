// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Core = @This();

general_purpose_allocator: std.mem.Allocator,

pub const CreationInfo = struct {};

pub fn init(
    creation_info: CreationInfo,
    general_purpose_allocator: std.mem.Allocator,
) !Core {
    _ = creation_info;
    return .{
        .general_purpose_allocator = general_purpose_allocator,
    };
}
