// SPDX-License-Identifier: MPL-2.0

const std = @import("std");

const Self = @This();

arena: std.heap.ArenaAllocator,
parsed_json: std.json.Parsed(std.json.Value),

format_version: i64,
action: []const u8,
source_path: []const u8,
source_json: std.json.Value,
source_string: []const u8,

pub fn init(
    gpa: std.mem.Allocator,
    path: []u8,
) !Self {
    var arena = std.heap.ArenaAllocator.init(gpa);
    var arena_allocator = arena.allocator();

    const file = try std.fs.cwd().openFile(path, .{
        .mode = std.fs.File.OpenMode.read_only,
    });
    defer file.close();

    const source = try file.readToEndAlloc(
        std.heap.smp_allocator,
        std.math.maxInt(u32),
    );

    const parsed_json = try std.json.parseFromSlice(
        std.json.Value,
        arena_allocator,
        source,
        .{ .duplicate_field_behavior = .use_last },
    );
    const json = parsed_json.value;

    if (json != .object) {
        return ParserError.RootNotAnObject;
    }

    const format_version = json.object.get("format_version");
    if (format_version == null) {
        return ParserError.FormatVersionMissing;
    }

    if (format_version.?.integer != 1) {
        return ParserError.UnuspportedFormatVersion;
    }

    const action_string = json.object.get("action");
    if (action_string == null) {
        return ParserError.ActionMissing;
    }

    return .{
        .arena = arena,
        .format_version = format_version.?.integer,
        .action = try arena_allocator.dupe(u8, action_string.?.string),
        .parsed_json = parsed_json,
        .source_json = parsed_json.value,
        .source_path = path,
        .source_string = source,
    };
}

pub fn deinit(
    self: Self,
) void {
    // This function only exists because in the future, some more fields could
    // exist that aren't allocated with the arena allocator, making more steps
    // necessary for free'ing the structure.

    self.arena.deinit();
}

pub const ParserError = error{
    RootNotAnObject,
    FormatVersionMissing,
    UnuspportedFormatVersion,
    ActionMissing,
};
