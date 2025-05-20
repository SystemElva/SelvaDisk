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

// Functions Region

pub fn deinit(self: *Self) void {
    self.shared_library.close();
}
