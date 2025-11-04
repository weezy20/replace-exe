/// This file demonstrates a self-updating Zig executable.
/// If this Demo is V1 it will replace itself with Demo2 (V2) (expected to be in zig-out/bin/demo2) and continues running the new version.
const std = @import("std");
const Io = std.Io;
const replace_exe = @import("replace-exe");

const SEMVER = "V2";

pub fn main() !void {
    const d = Demo{};
    const allocator = std.heap.page_allocator;
    var updated: bool = false;
    d.print("Before:");
    if (std.mem.eql(u8, SEMVER, "V1")) {
        std.log.info("V1: Starting update...", .{});
        replace_exe.selfReplace(allocator, "zig-out/bin/demo2") catch |err| {
            std.log.err("Failed to replace executable: {s}", .{err});
            return err;
        };
        updated = true;
    }
    if (updated) std.log.info("Update complete!", .{});
    d.print("After:");
}

const Demo = struct {
    fn print(_: *const Demo, prefix: []const u8) void {
        std.log.info("{s} Demo version: {s}", .{ prefix, SEMVER });
    }
};
