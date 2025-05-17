// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const arguments = @import("arguments.zig");
const selvafat = @import("SelvaFat.zig");

pub const Api = @import("SelvaDiskApi.zig");
const Addon = @import("Addon.zig");

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

    var filesystem_driver_registry = Api.FilesystemDriver.Registry.init(
        std.heap.smp_allocator,
    );
    var addon = try Addon.init(
        &filesystem_driver_registry,
        ".addons/libSelvaDiskAddon-FatFs.so",
    );
    defer addon.deinit();

    return 0;
}
