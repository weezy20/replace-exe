const std = @import("std");
const windows = std.os.windows;
const SELFDELETE_SUFFIX: []const u8 = ".__selfdelete__.exe";
const TEMP_SUFFIX: []const u8 = ".__temp__.exe";
const RELOCATED_SUFFIX: []const u8 = ".__relocated__.exe";

pub fn selfDeleteInit() void {}

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
    // Path to current-exe absolute
    const current_exe = try std.fs.selfExePath(&pathbuf);
    // Path to windows temp dir
    const windows_temp_dir = std.process.getEnvVarOwned(allocator, "TEMP") catch
        std.process.getEnvVarOwned(allocator, "TMP") catch null;
    defer if (windows_temp_dir) |dir| allocator.free(dir);

    // Strategy 1: Use %TEMP% for relocated & self-delete helper
    if (windows_temp_dir) |tmp| {
        const relocated_exe = try getTmpExePath(allocator, current_exe, tmp, RELOCATED_SUFFIX);
        defer allocator.free(relocated_exe);

        // Try to rename current exe to temp dir
        if (std.fs.renameAbsolute(current_exe, relocated_exe)) {
            // Success! Now create delete helper and spawn
            const tmp_exe = try getTmpExePath(allocator, current_exe, tmp, SELFDELETE_SUFFIX);
            defer allocator.free(tmp_exe);

            try std.fs.copyFileAbsolute(relocated_exe, tmp_exe, .{});
            try spawnTmpExeToDeleteParent(allocator, tmp_exe, relocated_exe);
            return;
        } else |_| {
            // Rename failed, fall through to next strategy
        }
    }
    // Strategy 2: Use exclude_path parent if provided
    if (exclude_path) |path| {
        const parent = std.fs.path.dirname(path) orelse return error.NoParentForExcludePath;

        const tmp_exe = try getTmpExePath(allocator, current_exe, parent, SELFDELETE_SUFFIX);
        defer allocator.free(tmp_exe);

        const relocated_exe = try getTmpExePath(allocator, current_exe, parent, RELOCATED_SUFFIX);
        defer allocator.free(relocated_exe);

        try std.fs.copyFileAbsolute(current_exe, tmp_exe, .{});
        try std.fs.renameAbsolute(current_exe, relocated_exe);
        try spawnTmpExeToDeleteParent(allocator, tmp_exe, relocated_exe);
        return;
    }

    // Parent dir for current exe
    const exe_base_dir = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_base_dir);

    const tmp_exe = try getTmpExePath(allocator, current_exe, exe_base_dir, SELFDELETE_SUFFIX);
    defer allocator.free(tmp_exe);

    try std.fs.copyFileAbsolute(current_exe, tmp_exe, .{});
    try spawnTmpExeToDeleteParent(allocator, tmp_exe, current_exe);
}

/// Creates a temporary executable path with a random name in the given directory and
/// the provided suffix. Returns path/to/temp_exe. Caller owns the memory.
fn getTmpExePath(
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

    var rng = std.Random.DefaultPrng.init(@as(u64, @bitCast(std.time.timestamp())));
    const random = rng.random();

    try temp_name.append(allocator, '.');

    const stem = std.fs.path.stem(basename);
    try temp_name.appendSlice(allocator, stem);
    try temp_name.append(allocator, '.');

    // Generate 32 random lowercase letters
    const lowercase = "abcdefghijklmnopqrstuvwxyz";
    for (0..32) |_| {
        const idx = random.intRangeAtMost(usize, 0, lowercase.len - 1);
        try temp_name.append(allocator, lowercase[idx]);
    }

    try temp_name.appendSlice(allocator, suffix);

    return std.fs.path.join(allocator, &.{ base_dir, temp_name.items });
}

// const GENERIC_READ: windows.DWORD = 0x80000000;
// const FILE_SHARE_READ: windows.DWORD = 0x00000001;
// const FILE_SHARE_DELETE: windows.DWORD = 0x00000004;
// const OPEN_EXISTING: windows.DWORD = 3;
// const FILE_FLAG_DELETE_ON_CLOSE: windows.DWORD = 0x04000000;
// const DUPLICATE_SAME_ACCESS: windows.DWORD = 0x00000002;

// const SECURITY_ATTRIBUTES = extern struct {
//     nLength: windows.DWORD,
//     lpSecurityDescriptor: ?*anyopaque,
//     bInheritHandle: windows.BOOL,
// };

// extern "kernel32" fn DuplicateHandle(
//     hSourceProcessHandle: windows.HANDLE,
//     hSourceHandle: windows.HANDLE,
//     hTargetProcessHandle: windows.HANDLE,
//     lpTargetHandle: *windows.HANDLE,
//     dwDesiredAccess: windows.DWORD,
//     bInheritHandle: windows.BOOL,
//     dwOptions: windows.DWORD,
// ) callconv(windows.WINAPI) windows.BOOL;

/// Spawns the temporary exe and instructs it to delete the parent exe.
/// The child will wait until the parent process exits, then delete the target file.
fn spawnTmpExeToDeleteParent(
    allocator: std.mem.Allocator,
    tmp_exe: []const u8,
    original_exe: []const u8,
) !void {
    _ = .{ allocator, tmp_exe, original_exe };
}
