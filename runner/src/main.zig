// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Core = @import("SelvaDiskCore");

pub fn main() !u8 {
    const stderr = std.io.getStdErr();
    if (std.os.argv.len != 2) {
        try std.fmt.format(
            stderr.writer(),
            "error(runner) :: invalid usage, try:\n  $ {s}\n",
            .{std.os.argv[0]},
        );
        return 1;
    }

    const sentinel_terminated_extension_path = std.os.argv[1];
    const len_sentinel_terminated_extension_path = std.mem.len(sentinel_terminated_extension_path);

    const extension_path_slice = sentinel_terminated_extension_path[0..len_sentinel_terminated_extension_path];

    const extension_path =
        try switch (std.fs.path.isAbsolute(extension_path_slice)) {
            true => std.heap.smp_allocator.dupe(
                u8,
                extension_path_slice,
            ),
            false => std.fs.cwd().realpathAlloc(
                std.heap.smp_allocator,
                extension_path_slice,
            ),
        };

    var core = Core.init(
        .{ .extension_folder_path = extension_path },
        std.heap.smp_allocator,
    ) catch |err| {
        switch (err) {
            Core.Error.OutOfMemory => {
                try std.fmt.format(
                    stderr.writer(),
                    "error(runner) :: failed initializing core due to lack of memory",
                    .{},
                );
                return 2;
            },
            Core.Error.ExtensionFolderOpenError => {
                try std.fmt.format(
                    stderr.writer(),
                    "error(core) :: failed opening extension folder",
                    .{},
                );
                return 3;
            },
            Core.Error.ExtensionFolderAccessDenied => {
                try std.fmt.format(
                    stderr.writer(),
                    "error(core) :: failed opening extension folder: access denied",
                    .{},
                );
                return 4;
            },
            error.FormattingFailure => {
                try std.fmt.format(
                    stderr.writer(),
                    "error(core) :: failed formatting error while initializing core, further details are unknown",
                    .{},
                );
                return 5;
            },
            else => {
                try std.fmt.format(
                    stderr.writer(),
                    "error(runner) :: failed initializing core: {s}",
                    .{@errorName(err)},
                );
                return 6;
            },
        }
    };
    defer core.deinit();

    return 0;
}
