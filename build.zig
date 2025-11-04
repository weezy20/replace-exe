const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const so = b.option(bool, "shared", "Build shared library: libreplace-exe.so") orelse false;

    switch (target.result.os.tag) {
        .windows, .linux, .macos, .freebsd, .netbsd, .dragonfly, .openbsd => {},
        else => {
            std.log.err("Unsupported Target OS: {s}", .{@tagName(target.result.os.tag)});
            std.log.err("Supported: Windows, Linux, macOS, FreeBSD, NetBSD, DragonFly, OpenBSD", .{});
            std.process.exit(1);
        },
    }

    // Create module for the library
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .name = "replace-exe",
        .linkage = if (so) .dynamic else .static,
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    // Tests
    const lib_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_tests.step);

    const demo_exe = b.addExecutable(.{
        .name = "demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demo/demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    demo_exe.root_module.addImport("replace-exe", lib_mod);
    demo_exe.linkLibrary(lib);

    const demo_exe2 = b.addExecutable(.{
        .name = "demo2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demo/demo2.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    demo_exe2.root_module.addImport("replace-exe", lib_mod);
    demo_exe2.linkLibrary(lib);

    if (b.option(bool, "demo", "Build demo executable") orelse false) {
        b.installArtifact(demo_exe);
        b.installArtifact(demo_exe2);
    }
}
