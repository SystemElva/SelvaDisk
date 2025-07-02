// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Extension = @import("Extension.zig");
const Core = @This();

extensions: std.ArrayList(Extension),

allocator: std.mem.Allocator,

pub const CreationInfo = struct {
    extension_folder_path: []const u8 = ".extensions/",
};

pub const Error = error{
    OutOfMemory,
    ExtensionFolderOpenError,
    ExtensionFolderAccessDenied,
    ExtensionLinkageFailure,
    ExtensionAccessDenied,
    InvalidDynamicLibrary,
    DynamicLibraryMissingSetupFunction,
    DynamicLibraryOpenError,
    FormattingFailure,
};

pub fn init(
    creation_info: CreationInfo,
    allocator: std.mem.Allocator,
) Error!Core {
    var work_arena_head = std.heap.ArenaAllocator.init(allocator);
    defer work_arena_head.deinit();
    const work_arena = work_arena_head.allocator();

    var extension_folder = std.fs.openDirAbsolute(
        creation_info.extension_folder_path,
        .{ .iterate = true },
    ) catch {
        return Error.ExtensionFolderOpenError;
    };

    var extension_folder_iterator = extension_folder.iterate();
    var extension_folder_item: ?std.fs.Dir.Entry = extension_folder_iterator.next() catch |err| {
        switch (err) {
            error.AccessDenied => {
                return Error.ExtensionFolderAccessDenied;
            },

            error.Unexpected, error.SystemResources, error.InvalidUtf8 => {
                return Error.ExtensionFolderOpenError;
            },
        }
    };

    var extensions = std.ArrayList(Extension).init(allocator);
    while (extension_folder_item != null) {
        if (extension_folder_item.?.kind == .file) {
            // This extension path is only temporary because it will be
            // deallocated with the work_arena once this function returns.
            const temporary_extension_path = std.fs.path.join(work_arena, &[2][]const u8{
                creation_info.extension_folder_path,
                extension_folder_item.?.name,
            }) catch |err| {
                switch (err) {
                    error.OutOfMemory => {
                        return Error.OutOfMemory;
                    },
                }
            };
            var try_append = true;
            const extension = Extension.init(
                allocator,
                temporary_extension_path,
            ) catch |err| {
                try_append = false;
                const stderr = std.io.getStdErr().writer();
                switch (err) {
                    Error.InvalidDynamicLibrary => {
                        std.fmt.format(
                            stderr,
                            "warn(core): malformatted dynamic extension library at path:\n{s}\n",
                            .{temporary_extension_path},
                        ) catch {
                            return Error.FormattingFailure;
                        };
                    },
                    Error.ExtensionAccessDenied => {
                        std.fmt.format(
                            stderr,
                            "warn(core): inaccessible dynamic extension library at path:\n{s}\n",
                            .{temporary_extension_path},
                        ) catch {
                            return Error.FormattingFailure;
                        };
                    },
                    Error.OutOfMemory => {
                        std.fmt.format(
                            stderr,
                            "warn(core): failed loading dynamic extension library due to lack of memory\n",
                            .{},
                        ) catch {
                            return Error.FormattingFailure;
                        };
                    },
                    Error.DynamicLibraryOpenError => {
                        std.fmt.format(
                            stderr,
                            "warn(core): failed loading dynamic extension library at path:\n{s}\n",
                            .{temporary_extension_path},
                        ) catch {
                            return Error.FormattingFailure;
                        };
                    },
                    error.ExtensionLinkageFailure => {
                        std.fmt.format(
                            stderr,
                            "warn(core): failed linking dynamic extension library at path:\n{s}\n",
                            .{temporary_extension_path},
                        ) catch {
                            return Error.FormattingFailure;
                        };
                    },
                    else => {
                        break;
                    },
                }
                return err;
            };
            if (try_append) {
                try extensions.append(extension);
            }
        }

        // Get the next accessible item
        while (true) {
            extension_folder_item = extension_folder_iterator.next() catch {
                continue;
            };
            break;
        }
    }

    var core: Core = .{
        .allocator = allocator,
        .extensions = extensions,
    };

    var extension_index: usize = 0;
    while (extension_index < extensions.items.len) {
        if (!extensions.items[extension_index].setup(&core)) {
            _ = extensions.swapRemove(extension_index);
        }
        extension_index += 1;
    }

    return core;
}

pub fn deinit(core: Core) void {
    core.extensions.deinit();
}
