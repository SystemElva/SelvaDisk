// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const arguments = @import("arguments.zig");
const selvafat = @import("SelvaFat.zig");

pub const Api = @import("SelvaDiskApi.zig");
const addons = @import("addons.zig");

const DiskDescription = @import("script/DiskDescription.zig");
pub fn main() !u8 {
    var initialization_arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer initialization_arena.deinit();

    const argument_set = arguments.ArgumentSet.parseZ(
        std.os.argv[1..],
        initialization_arena.allocator(),
    ) catch |err| {
        std.log.err("failed parsing arguments ({s})", .{@errorName(err)});
        return 1;
    };

    const folder_path = try std.fs.selfExeDirPathAlloc(std.heap.smp_allocator);

    const path_elements: [2][]const u8 = .{ folder_path, ".addons" };
    const addon_folder_path = try std.fs.path.join(
        initialization_arena.allocator(),
        &path_elements,
    );

    var api = try Api.init(
        addon_folder_path,
        std.heap.c_allocator,
    );
    defer api.deinit();
    try api.setupAllAddons();

    const description = Api.Description.init(
        std.heap.smp_allocator,
        argument_set.script_path,
    ) catch {
        return 1;
    };

    api.partitionDisk(
        description,
        argument_set.output_path,
    ) catch {
        return 1;
    };

    return 0;
}
