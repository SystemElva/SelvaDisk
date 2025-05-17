const std = @import("std");
const api = @import("SelvaDiskApi.zig");

export fn initialize(
    addon: *api.Addon,
) callconv(.C) bool {
    _ = addon;
    std.debug.print("The Addon has been called!\n", .{});
    return true;
}
