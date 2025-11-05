const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const capi = b.option(bool, "capi", "Build shared library: libreplace-exe.so for use with C/C++") orelse false;
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
    const lib_mod = b.addModule("replace_exe", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // C API needs to import the core module and link libc
    if (capi) {
        const lib = b.addLibrary(.{
            .name = "replace-exe",
            .linkage = if (so) .dynamic else .static,
            .root_module = b.createModule(.{
                .root_source_file = b.path("c_api.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        lib.root_module.addImport("replace_exe", lib_mod);
        lib.linkLibC();

        // Install header file for C/C++ users
        const header = b.addInstallFile(b.path("include/replace_exe.h"), "include/replace_exe.h");
        b.getInstallStep().dependOn(&header.step);
        b.installArtifact(lib);
    }

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

    const demo_exe2 = b.addExecutable(.{
        .name = "demo2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demo/demo2.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    demo_exe2.root_module.addImport("replace-exe", lib_mod);

    if (b.option(bool, "demo", "Build demo executable") orelse false) {
        b.installArtifact(demo_exe);
        b.installArtifact(demo_exe2);
    }

    const run_demo = b.addRunArtifact(demo_exe);
    run_demo.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_demo.addArgs(args);
    }

    const run_step = b.step("run", "Run the demo executable");
    run_step.dependOn(&run_demo.step);
}
