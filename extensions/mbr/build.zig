// SPDX-License-Identifier: MPL-2.0

const std = @import("std");

pub fn build(build_process: *std.Build) void {
    const target = build_process.standardTargetOptions(.{});
    const optimize = build_process.standardOptimizeOption(.{});

    const lib_mod = build_process.addModule("SelvaDiskBuiltinMbr", .{
        .root_source_file = build_process.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const lib = build_process.addLibrary(.{
        .linkage = .dynamic,
        .name = "SelvaDiskBuiltinMbr",
        .root_module = lib_mod,
    });

    const selvadisk_core_dependency = build_process.dependency(
        "SelvaDiskCore",
        .{},
    );
    lib.root_module.addImport(
        "SelvaDiskCore",
        selvadisk_core_dependency.module("SelvaDiskCore"),
    );

    build_process.installArtifact(lib);

    const lib_unit_tests = build_process.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = build_process.addRunArtifact(lib_unit_tests);

    const test_step = build_process.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
