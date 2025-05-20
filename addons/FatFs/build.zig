// SPDX-License-Identifier: MPL-2.0

const std = @import("std");

pub fn build(build_process: *std.Build) void {
    const target = build_process.standardTargetOptions(.{});
    const optimize = build_process.standardOptimizeOption(.{});

    const lib_mod = build_process.addModule("SelvaDiskAddon-FatFs", .{
        .root_source_file = build_process.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const lib = build_process.addLibrary(.{
        .linkage = .dynamic,
        .name = "SelvaDiskAddon-FatFs",
        .root_module = lib_mod,
    });

    const selvadisk_api_package = build_process.dependency(
        "SelvaDiskApi",
        .{},
    );
    lib.root_module.addImport("SelvaDiskApi.zig", selvadisk_api_package.module("SelvaDiskApi"));
    build_process.installArtifact(lib);

    const lib_unit_tests = build_process.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = build_process.addRunArtifact(lib_unit_tests);

    const test_step = build_process.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
