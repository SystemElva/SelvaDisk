// SPDX-License-Identifier: MPL-2.0

const std = @import("std");

pub fn build(build_process: *std.Build) void {
    const target = build_process.standardTargetOptions(.{});
    const optimize = build_process.standardOptimizeOption(.{});

    // Add API module

    const core_module = build_process.addModule("selvadisk_core", .{
        .root_source_file = build_process.path("../core/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    _ = build_process.addLibrary(.{
        .linkage = .static,
        .name = "SelvaDiskCore",
        .root_module = core_module,
    });

    // Add core

    const executable = build_process.addExecutable(.{
        .name = "SelvaDisk",
        .root_source_file = build_process.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const core_dependency = build_process.dependency("selvadisk_core", .{});
    executable.root_module.addImport("selvadisk_core.zig", core_dependency.module("selvadisk_core"));

    build_process.installArtifact(executable);
    const run_command = build_process.addRunArtifact(executable);
    run_command.step.dependOn(build_process.getInstallStep());

    if (build_process.args) |args| {
        run_command.addArgs(args);
    }

    const run_step = build_process.step("run", "Execute the SelvaDisk Disk Image Creator");
    run_step.dependOn(&run_command.step);

    const executable_unit_tests = build_process.addTest(.{
        .root_source_file = build_process.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_executable_unit_tests = build_process.addRunArtifact(executable_unit_tests);

    const test_step = build_process.step("test", "Run all unit tests");
    test_step.dependOn(&run_executable_unit_tests.step);
}
