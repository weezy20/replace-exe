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
    if (allocator) |a| {
        return schedule_self_deletion_on_shutdown(a, exclude_path);
    } else {
        return error.NoAllocator;
    }
}

pub fn selfDelete(allocator: ?std.mem.Allocator) !void {
    if (allocator) |a| {
        return schedule_self_deletion_on_shutdown(a, null);
    } else {
        return error.NoAllocator;
    }
}

fn schedule_self_deletion_on_shutdown(allocator: std.mem.Allocator, exclude_path: ?[]const u8) !void {
    var pathbuf: [std.fs.max_path_bytes]u8 = undefined;
    const current_exe = try std.fs.selfExePath(&pathbuf);

    const exe_base_dir = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_base_dir);

    const base_dir = if (exclude_path) |path| blk: {
        // Try to get parent directory of exclude_path
        if (std.fs.path.dirname(path)) |parent| {
            break :blk try allocator.dupe(u8, parent);
        } else {
            // If no parent, fall back to exe_base_dir (no allocation needed)
            break :blk exe_base_dir;
        }
    } else exe_base_dir;

    // Only free base_dir if it's not the same as exe_base_dir
    defer if (base_dir.ptr != exe_base_dir.ptr) allocator.free(base_dir);

    const temp_exe = try getTempExecutable(allocator, current_exe, base_dir, SELFDELETE_SUFFIX);
    defer allocator.free(temp_exe);
    // defer allocator.free(temp_exe);
    std.debug.print("temp exe : {s}", .{temp_exe});
}

/// Creates a temporary executable with a random name in the given directory and
/// the provided suffix. Returns path/to/temp_exe. Caller owns the memory.
fn getTempExecutable(
    allocator: std.mem.Allocator,
    /// Path to current exe
    current_exe: []const u8,
    /// Base dir where to create the temp exe
    base_dir: []const u8,
    /// temp exe suffix
    suffix: []const u8,
) ![]u8 {
    const basename = std.fs.path.basenameWindows(current_exe);
    var temp_name = try std.ArrayList(u8).initCapacity(allocator, base_dir.len + 32 + 2 + basename.len + suffix.len);
    defer temp_name.deinit(allocator);

    var rng = std.Random.DefaultPrng.init(@as(u64, @bitCast(std.time.nanoTimestamp())));
    const random = rng.random();

    try temp_name.append('.');

    const stem = std.fs.path.stem(basename);
    try temp_name.appendSlice(stem);
    try temp_name.append('.');

    // Generate 32 random lowercase letters
    const lowercase = "abcdefghijklmnopqrstuvwxyz";
    for (0..32) |_| {
        const idx = random.intRangeAtMost(usize, 0, lowercase.len - 1);
        try temp_name.append(lowercase[idx]);
    }

    try temp_name.appendSlice(suffix);

    return std.fs.path.join(allocator, &.{ base_dir, temp_name.items });
}
