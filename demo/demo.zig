/// This file demonstrates a self-updating Zig executable.
/// If this Demo is V1 it will replace itself with Demo2 (V2) (expected to be in zig-out/bin/demo2) and continues running the new version.
const std = @import("std");
const replace_exe = @import("replace-exe");

const SEMVER = "V1";

pub fn main() !void {
    replace_exe.registerHooks(); // Must be first on Windows

    const native_os = @import("builtin").os.tag;
    const allocator = std.heap.page_allocator;
    var args = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // skip exe name
    const cmd = args.next() orelse {
        std.log.err("Usage: demo <replace|delete> [new_executable_path]", .{});
        std.process.exit(1);
    };
    const d = Demo{};
    var updated: bool = false;
    d.print("Before:");
    if (std.mem.eql(u8, SEMVER, "V1")) {
        if (std.mem.eql(u8, cmd, "replace")) {
            // Here demo2 is a new exe that must replace demo1 or demo
            replace_exe.selfReplace(allocator, args.next() orelse "zig-out/bin/demo2") catch |err| {
                std.log.err("Failed to replace executable: {}", .{err});
                return err;
            };
            updated = true;
        } else if (std.mem.eql(u8, cmd, "delete")) {
            std.log.info("V1: Deleting self...", .{});
            try replace_exe.selfDelete(switch (native_os) {
                .windows => allocator,
                else => null,
            });
            std.log.info("V1: Self-delete succeeded.", .{});
        } else {
            return error.InvalidArguments;
        }
    }
    if (updated) std.log.info("Update complete!", .{});
    d.print("After:");
}

const Demo = struct {
    fn print(_: *const Demo, prefix: []const u8) void {
        std.log.info("{s} Demo version: {s}", .{ prefix, SEMVER });
    }
};
