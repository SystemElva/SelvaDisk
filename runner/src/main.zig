const std = @import("std");
const Core = @import("SelvaDiskCore");

pub fn main() void {
    var core = try Core.init(
        .{},
        std.heap.smp_allocator,
    );
    defer core.deinit();
}
