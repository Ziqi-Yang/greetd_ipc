const std = @import("std");
const Path = std.fs.path;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const option_example = b.option([]const u8, "example", "The path for the example to be built. e.g. examples/demo.zig");
    const example_path = option_example orelse "examples/demo.zig";
    const example_name = Path.stem(example_path);

    // Tests
    const greetd_ipc_tests = b.addTest(.{
        .root_source_file = b.path("src/greetd_ipc.zig"),
        .target = target,
        .optimize = optimize
    });
    const run_greetd_ipc_tests = b.addRunArtifact(greetd_ipc_tests);
    const test_step = b.step("test", "Run greetd_ipc library tests");
    test_step.dependOn(&run_greetd_ipc_tests.step);

    // Docs
    const greetd_ipc_docs = greetd_ipc_tests;
    const build_docs = b.addInstallDirectory(.{
        .source_dir = greetd_ipc_docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "../docs"
    });
    const build_docs_step = b.step("docs", "Build the greetd_ipc libarary docs");
    build_docs_step.dependOn(&build_docs.step);

    // Lib module
    const greetd_ipc_mod = b.addModule("greetd_ipc", .{
        .root_source_file = b.path("src/greetd_ipc.zig"),
        .target = target,
        .optimize = optimize
    });

    // Example exe
    const greetd_ipc_example = b.addExecutable(.{
        .name = example_name,
        .root_source_file = b.path(example_path),
        .target = target,
        .optimize = optimize
    });
    greetd_ipc_example.root_module.addImport("greetd_ipc", greetd_ipc_mod);

    // - build example exe
    const build_greetd_ipc_example = b.addInstallArtifact(greetd_ipc_example, .{});
    const build_greetd_ipc_example_step = b.step("build-example", "Build example");
    build_greetd_ipc_example_step.dependOn(&build_greetd_ipc_example.step);

    // - run example exe
    const run_greetd_ipc_example = b.addRunArtifact(greetd_ipc_example);
    run_greetd_ipc_example.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_greetd_ipc_example.addArgs(args);
    }
    const run_greetd_ipc_example_step = b.step("run-example", "Run example");
    run_greetd_ipc_example_step.dependOn(&run_greetd_ipc_example.step);
}
