// SPDX-License-Identifier: MPL-2.0

const std = @import("std");
const Api = @import("SelvaDiskApi.zig");
const creation = @import("creation.zig");

const mbr_partitioning_scheme_label: []const u8 = "mbr";

export fn initialize(
    self: *Api.Addon,
    api: *Api,
) callconv(.C) bool {
    const partitioning_scheme: Api.Addon.PartitioningScheme = .{
        .partition_disk = creation.create_mbr_disk,
        .label = &mbr_partitioning_scheme_label,
    };
    const status = api.registerPartitioningScheme(self, &partitioning_scheme);
    if (!status) {
        return false;
    }

    return true;
}
