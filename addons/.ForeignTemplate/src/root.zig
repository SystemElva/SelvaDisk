const std = @import("std");
const api = @import("SelvaDiskApi.zig");

export fn initialize(
    addon: *api.Addon,
) callconv(.C) bool {

    // Write initialization code here.

    _ = addon;
    std.debug.print("The Foreign Template has been called!\n", .{});
    return true;
}
