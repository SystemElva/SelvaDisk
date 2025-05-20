// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Api = @import("SelvaDiskApi.zig");

export fn create_fat12(
    self: *Api.Addon,
    filesystem_json: *std.json.Value,
) callconv(.C) bool {
    _ = self;
    _ = filesystem_json;

    std.debug.print("Creating FAT12 filesystem!\n", .{});
    return true;
}

const fat12_filesystem_label: []const u8 = "fat12";

export fn initialize(
    self: *Api.Addon,
    api: *Api,
) callconv(.C) bool {
    const filesystem: Api.Addon.Filesystem = .{
        .create = create_fat12,
        .label = &fat12_filesystem_label,
    };
    const status = api.registerFilesystemCreator(self, &filesystem);
    if (!status) {
        return false;
    }

    return true;
}
