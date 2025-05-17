// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const arguments = @import("arguments.zig");
const selvafat = @import("SelvaFat.zig");

pub const api = @import("SelvaDiskApi.zig");
const addons = @import("addons.zig");

const DiskDescription = @import("script/DiskDescription.zig");
pub fn main() !u8 {
    const argument_set = arguments.ArgumentSet.parseZ(
        std.os.argv[1..],
        std.heap.smp_allocator,
    ) catch |err| {
        std.log.err("failed parsing arguments ({s})", .{@errorName(err)});
        return 1;
    };
    _ = argument_set;
    _ = try addons.load_all_plugins();

    return 0;
}
