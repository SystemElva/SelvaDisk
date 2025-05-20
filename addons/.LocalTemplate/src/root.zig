const std = @import("std");
const api = @import("SelvaDiskApi.zig");

export fn initialize(
    driver_registry: *api.FilesystemDriver.Registry,
) callconv(.C) bool {

    // Write initialization code here.

    std.debug.print("The Addon Template has been called!\n", .{});
    return true;
}
