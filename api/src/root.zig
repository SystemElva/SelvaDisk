// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
pub const Addon = @import("Addon.zig");

pub const Error = error{
    FilesystemDriverNotFound,
    NoInitializationFunction,
    InitializationFailed,
};
