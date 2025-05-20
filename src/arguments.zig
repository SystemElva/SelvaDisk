// SPDX-License-Identifier: MPL-2.0

const std = @import("std");

pub const ArgumentSet = struct {
    const Self = @This();

    script_path: []u8,
    output_path: []u8,

    const Accept = enum(u16) {
        all,
        output_path,
    };

    pub const ParserError = error{
        MissingValueAtEnd,
        NoOutputPathGiven,
        NoScriptPathGiven,
        AllocationError,
        PathResolutonFailure,
    };

    pub fn parse(
        arguments: [][]u8,
        allocator: std.mem.Allocator,
    ) ParserError!Self {
        var output_path: ?[]u8 = null;
        var script_path: ?[]u8 = null;

        var accept = Accept.all;
        var argument_index: usize = 0;
        while (argument_index < arguments.len) {
            const argument = arguments[argument_index];

            switch (accept) {
                Accept.all => {
                    if (std.mem.eql(u8, argument, "-o")) {
                        argument_index += 1;
                        accept = Accept.output_path;
                        continue;
                    }
                    if (std.mem.eql(u8, argument, "--output")) {
                        argument_index += 1;
                        accept = Accept.output_path;
                        continue;
                    }
                    if (std.mem.startsWith(u8, argument, "-o=")) {
                        if (argument.len > 3) {
                            const work_folder_path = std.fs.cwd().realpathAlloc(
                                allocator,
                                ".",
                            ) catch {
                                return ParserError.PathResolutonFailure;
                            };

                            defer allocator.free(work_folder_path);
                            output_path = std.fs.path.resolve(
                                allocator,
                                &[2][]const u8{ work_folder_path, argument },
                            ) catch {
                                return ParserError.PathResolutonFailure;
                            };
                        }
                        argument_index += 1;
                        continue;
                    }
                    if (std.mem.startsWith(u8, argument, "--output=")) {
                        if (argument.len > 9) {
                            const work_folder_path = std.fs.cwd().realpathAlloc(
                                allocator,
                                ".",
                            ) catch {
                                return ParserError.PathResolutonFailure;
                            };
                            defer allocator.free(work_folder_path);

                            output_path = std.fs.path.resolve(
                                allocator,
                                &[2][]const u8{ work_folder_path, argument },
                            ) catch {
                                return ParserError.PathResolutonFailure;
                            };
                        }
                        argument_index += 1;
                        continue;
                    }

                    const work_folder_path = std.fs.cwd().realpathAlloc(
                        allocator,
                        ".",
                    ) catch {
                        return ParserError.PathResolutonFailure;
                    };
                    defer allocator.free(work_folder_path);

                    script_path = std.fs.path.resolve(
                        allocator,
                        &[2][]const u8{ work_folder_path, argument },
                    ) catch {
                        return ParserError.PathResolutonFailure;
                    };
                },
                Accept.output_path => {
                    const work_folder_path = std.fs.cwd().realpathAlloc(
                        allocator,
                        ".",
                    ) catch {
                        return ParserError.PathResolutonFailure;
                    };
                    defer allocator.free(work_folder_path);

                    output_path = std.fs.path.resolve(
                        allocator,
                        &[2][]const u8{ work_folder_path, argument },
                    ) catch {
                        return ParserError.PathResolutonFailure;
                    };
                },
            }
            accept = Accept.all;
            argument_index += 1;
        }
        if (accept != Accept.all) {
            return ParserError.MissingValueAtEnd;
        }
        if (output_path == null) {
            return ParserError.NoOutputPathGiven;
        }
        if (script_path == null) {
            return ParserError.NoScriptPathGiven;
        }
        return .{
            .output_path = output_path.?,
            .script_path = script_path.?,
        };
    }

    pub fn parseZ(
        arguments: [][*:0]u8,
        allocator: std.mem.Allocator,
    ) ParserError!Self {
        var argument_duplicates = allocator.alloc([]u8, arguments.len) catch {
            return ParserError.AllocationError;
        };
        defer allocator.free(argument_duplicates);

        for (arguments, 0..) |argument, index| {
            const len_argument = std.mem.len(argument);
            argument_duplicates[index] = allocator.alloc(u8, len_argument) catch {
                return ParserError.AllocationError;
            };
            @memcpy(
                argument_duplicates[index],
                arguments[index],
            );
        }
        return try Self.parse(argument_duplicates, allocator);
    }

    pub fn writeToFile(self: Self, file: std.fs.File) !void {
        try std.fmt.format(
            file.writer(),
            "script_path: {s}\n",
            .{self.script_path.?},
        );
        try std.fmt.format(
            file.writer(),
            "output_path: {s}\n",
            .{self.output_path.?},
        );
    }
};
