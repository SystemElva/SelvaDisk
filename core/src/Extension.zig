// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const services = @import("services.zig");
const Core = @import("root.zig");

const Extension = @This();

// Fields

specifics: ?*anyopaque,
permanent_arena_head: std.heap.ArenaAllocator,

path: []const u8,

disk_partitioners: std.ArrayList(services.DiskPartitioner),
filesystem_drivers: std.ArrayList(services.FilesystemDriver),
postprocessors: std.ArrayList(services.Postprocessor),

fn_setup: FnSetup,
fn_cleanup: ?FnCleanup,

dynamic_library: std.DynLib,

// Definitions

pub const FnSetup = (*fn (
    core: *Core,
    specifics: *Extension,
) callconv(.c) bool);

pub const FnCleanup = (*fn (
    extension: *Extension,
) callconv(.c) void);

pub const FnRequestResource = (*fn (
    extension: *Extension,
    resource_name: *[]const u8,
    api_version: usize,
) callconv(.c) ?*anyopaque);

// Functions

pub fn init(
    allocator: std.mem.Allocator,
    extension_path: []const u8,
) Core.Error!Extension {
    var dynamic_library = std.DynLib.open(extension_path) catch |dynlib_err| {
        switch (dynlib_err) {
            error.OutOfMemory => {
                return Core.Error.OutOfMemory;
            },
            error.AccessDenied, error.PermissionDenied => {
                return Core.Error.ExtensionAccessDenied;
            },
            error.NotElfFile,
            error.NotDynamicLibrary,
            error.MissingDynamicLinkingInformation,
            error.ElfStringSectionNotFound,
            error.ElfSymSectionNotFound,
            error.ElfHashTableNotFound,
            => {
                return Core.Error.InvalidDynamicLibrary;
            },
            else => {
                return Core.Error.DynamicLibraryOpenError;
            },
        }
    };

    const nullable_fn_setup = dynamic_library.lookup(FnSetup, "selva_setup");

    if (nullable_fn_setup == null) {
        return Core.Error.DynamicLibraryMissingSetupFunction;
    }

    const nullable_fn_cleanup = dynamic_library.lookup(FnCleanup, "selva_cleanup");
    const extension = Extension{
        .path = extension_path,

        .disk_partitioners = .init(allocator),
        .filesystem_drivers = .init(allocator),
        .postprocessors = .init(allocator),

        .fn_setup = nullable_fn_setup.?,
        .fn_cleanup = nullable_fn_cleanup,

        .specifics = null,
        .dynamic_library = dynamic_library,
        .permanent_arena_head = std.heap.ArenaAllocator.init(allocator),
    };

    return extension;
}

pub fn setup(self: *Extension, core: *Core) bool {
    return self.fn_setup(core, self);
}

pub fn run(self: *Extension) void {
    _ = self;
}

pub fn destroy(self: *Extension) void {
    if (self.fn_cleanup != null) {
        self.fn_cleanup.?(self);
    }
    self.dynamic_library.close();
    self.permanent_arena_head.deinit();
}
