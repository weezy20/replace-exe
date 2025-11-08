const std = @import("std");
const SELFDELETE_SUFFIX: []const u8 = ".__selfdelete__.exe";
const TEMP_SUFFIX: []const u8 = ".__temp__.exe";

pub fn selfReplace(allocator: std.mem.Allocator, new_exe_path: []const u8) !void {
    //TODO: implement
    _ = allocator;
    _ = new_exe_path;
    return;
}

pub fn selfDeleteExcludingPath(allocator: ?std.mem.Allocator, exclude_path: []const u8) !void {
    //TODO: implement
    _ = allocator;
    _ = exclude_path;
    return;
}

pub fn selfDelete(allocator: ?std.mem.Allocator) !void {
    const _allocator = if (allocator) |a| a else {
        return error.NoAllocator;
    };
    var pathbuf: [std.fs.max_path_bytes]u8 = undefined;
    const current_exe = try std.fs.selfExePath(&pathbuf);
    const exe_basename = try std.fs.path.basenameWindows(current_exe);
    const temp_exe_name = try std.fmt.allocPrint(_allocator, "{s}{d}{s}", .{ exe_basename, std.time.timestamp(), SELFDELETE_SUFFIX });
    defer _allocator.free(temp_exe_name);
    const temp_exe = try std.fs.realpathAlloc(
        _allocator,
    );
    // defer _allocator.free(temp_exe);
    std.debug.print("temp basename : {s}", .{temp_exe_name});
    return;
}
