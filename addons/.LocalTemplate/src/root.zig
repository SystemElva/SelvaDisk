const std = @import("std");
const Api = @import("SelvaDiskApi.zig");

export fn initialize(
    self: *Api.Addon,
    api: *Api,
) callconv(.C) bool {

    // Write initialization code here.

    _ = self;
    _ = api;

    std.debug.print("The local Addon Template has been called!\n", .{});
    return true;
}
