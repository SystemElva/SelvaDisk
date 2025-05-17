// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const api = @import("SelvaDiskApi.zig");

const Self = @This();

shared_library: std.DynLib,

pub const Error = error{
    NoInitializeFunction,
    InitializationFailed,
    SharedObjectLoaderFailure,
};

const FnInitialize = (*fn (
    driver_registry: *api.FilesystemDriver.Registry,
) callconv(.C) bool);

const FnInit = (*fn (*api.FilesystemDriver.Registry) bool);

pub fn init(
    driver_registry: *api.FilesystemDriver.Registry,
    path: []const u8,
) Error!Self {
    var shared_library = std.DynLib.open(path) catch {
        return Error.SharedObjectLoaderFailure;
    };
    const init_function = shared_library.lookup(
        FnInitialize,
        "initialize",
    );
    if (init_function == null) {
        return Error.NoInitializeFunction;
    }
    const checked_init = init_function.?;
    const status = checked_init(driver_registry);
    //_ = driver_registry;
    if (!status) {
        return Error.InitializationFailed;
    }

    return .{
        .shared_library = shared_library,
    };
}

pub fn deinit(self: *Self) void {
    self.shared_library.close();
}
