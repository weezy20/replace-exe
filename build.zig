const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const capi = b.option(bool, "capi", "Build libreplace-exe for use with C/C++") orelse false;
    const so = b.option(bool, "so", "Build shared library: libreplace-exe.so instead of default static lib") orelse false;
    const demo = b.option(bool, "demo", "Build & Install demo executables") orelse false;
    const native_os = target.result.os.tag;
    switch (native_os) {
        .windows, .linux, .macos, .freebsd, .netbsd, .dragonfly, .openbsd => {},
        else => {
            std.log.err("Unsupported Target OS: {s}", .{@tagName(target.result.os.tag)});
            std.log.err("Supported: Windows, Linux, macOS, FreeBSD, NetBSD, DragonFly, OpenBSD", .{});
            std.process.exit(1);
        },
    }
    const lib_mod = b.addModule("replace_exe", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });
    var c_lib: ?*std.Build.Step.Compile = null;
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
        lib.root_module.link_libc = true;
        lib.use_llvm = true; // Needed due to bug in debug ELF linker for linux : https://github.com/ziglang/zig/issues/25129
        c_lib = lib;
        const header = b.addInstallFile(b.path("include/replace_exe.h"), "include/replace_exe.h");
        b.getInstallStep().dependOn(&header.step);
    }

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

    if (c_lib) |lib| {
        const demo_c = b.addExecutable(.{ .name = "demo-c", .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }) });
        demo_c.root_module.addCSourceFile(.{ .file = b.path("demo/demo.c") });
        demo_c.root_module.link_libc = true;
        demo_c.root_module.linkLibrary(lib); // dynamic links to libreplace-exe.so from .zig-cache
        demo_c.addIncludePath(b.path("include"));
        if (demo) {
            b.installArtifact(demo_c);
        }
        b.installArtifact(lib);
    }

    if (demo) {
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
