const std = @import("std");
const Api = @import("SelvaDiskApi.zig");

export fn initialize(
    addon: *Api.Addon,
    api: Api,
) callconv(.C) bool {

    // Write initialization code here.

    _ = addon;
    _ = api;

    std.debug.print("The Foreign Template has been called!\n", .{});
    return true;
}
