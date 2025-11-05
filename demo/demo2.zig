const std = @import("std");

const SEMVER = "V2";

pub fn main() !void {
    std.log.info("Hello from Demo2 version: {s}", .{SEMVER});
}
