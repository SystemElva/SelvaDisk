// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const arguments = @import("arguments.zig");
const selvafat = @import("SelvaFat.zig");

pub const Api = @import("SelvaDiskApi.zig");
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

    var initialization_arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer initialization_arena.deinit();

    const folder_path = try std.fs.selfExeDirPathAlloc(std.heap.smp_allocator);

    const path_elements: [2][]const u8 = .{ folder_path, ".addons" };
    const addon_folder_path = try std.fs.path.join(
        initialization_arena.allocator(),
        &path_elements,
    );

    const file = std.fs.cwd().openFile(argument_set.script_path, .{
        .mode = std.fs.File.OpenMode.read_only,
    }) catch {
        std.log.err("failed opening script-ifle", .{});
        return 1;
    };
    defer file.close();

    const script_source = file.readToEndAlloc(
        std.heap.smp_allocator,
        std.math.maxInt(u32),
    ) catch {
        std.log.err("failed reading from script-file", .{});
        return 1;
    };

    const parsed_json = try std.json.parseFromSlice(
        std.json.Value,
        initialization_arena.allocator(),
        script_source,
        .{ .duplicate_field_behavior = .use_last },
    );
    defer parsed_json.deinit();
    var json = parsed_json.value;

    var api = try Api.init(
        addon_folder_path,
        std.heap.c_allocator,
    );
    defer api.deinit();

    try api.setupAllAddons();
    try api.partitionDisk(&json);
    try api.createFilesystem(null);

    return 0;
}
