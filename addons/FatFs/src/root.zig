const std = @import("std");
const api = @import("SelvaDiskApi.zig");

export fn initialize(
    driver_registry: *api.FilesystemDriver.Registry,
) callconv(.C) bool {
    _ = driver_registry;
    std.debug.print("The Addon has been called!\n", .{});
    return true;
}
