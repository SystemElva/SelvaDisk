// SPDX-License-Identifier: MPL-2.0

const std = @import("std");

export fn selva_setup() callconv(.C) bool {
    std.log.info("The MBR partitioning scheme driver has been called.", .{});

    return true;
}
