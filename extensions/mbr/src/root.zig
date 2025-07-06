// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Core = @import("SelvaDiskCore");

const Self = @This();

core: *Core,
allocator: std.mem.Allocator,

export fn selva_setup(
    core: *Core,
    extension: *Core.Extension,
) callconv(.C) bool {
    std.log.info("The MBR partitioning scheme driver has been called.", .{});

    const self: Self = .{ .core = core, .allocator = std.heap.smp_allocator };
    const self_pointer = self.allocator.create(Self) catch {
        return false;
    };
    self_pointer.* = self;

    // extension.disk_partitioners.append();
    extension.specifics = self_pointer;

    return true;
}
