const std = @import("std");
const windows = std.os.windows;
const SELFDELETE_SUFFIX: []const u8 = ".__selfdelete__.exe";
const TEMP_SUFFIX: []const u8 = ".__temp__.exe";
const RELOCATED_SUFFIX: []const u8 = ".__relocated__.exe";

// Track whether hooks have been registered via init() -> selfDeleteInit()
var hooks_registered: bool = false;

/// Must be called at the start of main() on Windows via `init()`
/// Checks if this process is a self-delete helper and handles cleanup if so.
pub fn selfDeleteInit(allocator: ?std.mem.Allocator) void {
    if (hooks_registered) return;
    hooks_registered = true;

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const exe_path = std.fs.selfExePath(&path_buf) catch return;

    // Check if we're running as a self-delete helper
    if (std.mem.endsWith(u8, exe_path, SELFDELETE_SUFFIX)) {
        performSelfDeleteCleanup(allocator) catch {
            std.process.exit(1);
        };
        std.process.exit(0);
    }
}

pub fn selfReplace(allocator: std.mem.Allocator, new_exe_path: []const u8) !void {
    // Abs path to new exe
    const new_exe_path_abs = try std.fs.realpathAlloc(allocator, new_exe_path);
    defer allocator.free(new_exe_path_abs);

    // Path to current-exe absolute
    var pathbuf: [std.fs.max_path_bytes]u8 = undefined;
    const current_exe = try std.fs.selfExePath(&pathbuf);

    // Abs path to parent dir for temp/relocated exes
    const parent_dir = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(parent_dir);

    // Free up original name by relocation rename current -> current.relocated
    const old_exe = try getTmpExePath(allocator, current_exe, parent_dir, RELOCATED_SUFFIX);
    defer allocator.free(old_exe);
    try std.fs.renameAbsolute(current_exe, old_exe);

    // Schedule relocated exe for deletion on shutdown
    try schedule_self_deletion_on_shutdown(allocator, old_exe, null);

    const temp_exe = try getTmpExePath(allocator, current_exe, parent_dir, TEMP_SUFFIX);
    defer allocator.free(temp_exe);
    try std.fs.copyFileAbsolute(new_exe_path_abs, temp_exe, .{});
    errdefer std.fs.deleteFileAbsolute(temp_exe);
    try std.fs.renameAbsolute(temp_exe, current_exe);
    return;
}

pub fn selfDeleteExcludingPath(allocator: ?std.mem.Allocator, exclude_path: []const u8) !void {
    if (!hooks_registered) return error.HooksNotRegistered;

    if (allocator) |a| {
        var pathbuf: [std.fs.max_path_bytes]u8 = undefined;
        // Path to current-exe absolute
        const current_exe = try std.fs.selfExePath(&pathbuf);
        return schedule_self_deletion_on_shutdown(a, current_exe, exclude_path);
    } else {
        return error.NoAllocator;
    }
}

pub fn selfDelete(allocator: ?std.mem.Allocator) !void {
    if (!hooks_registered) return error.HooksNotRegistered;

    if (allocator) |a| {
        var pathbuf: [std.fs.max_path_bytes]u8 = undefined;
        // Path to current-exe absolute
        const current_exe = try std.fs.selfExePath(&pathbuf);
        return schedule_self_deletion_on_shutdown(a, current_exe, null);
    } else {
        return error.NoAllocator;
    }
}

fn schedule_self_deletion_on_shutdown(allocator: std.mem.Allocator, current_exe: []const u8, exclude_path: ?[]const u8) !void {
    // Strategy 1: Try %TEMP% if it's on the same drive as the executable
    const windows_temp_dir = std.process.getEnvVarOwned(allocator, "TEMP") catch
        std.process.getEnvVarOwned(allocator, "TMP") catch null;
    defer if (windows_temp_dir) |dir| allocator.free(dir);

    if (windows_temp_dir) |tmp| {
        // Check if TEMP is on the same drive as current_exe
        const exe_drive = getDriveLetter(current_exe);
        const tmp_drive = getDriveLetter(tmp);

        if (exe_drive != null and tmp_drive != null and exe_drive.? == tmp_drive.?) {
            // Same drive - we can use rename
            const relocated_exe = try getTmpExePath(allocator, current_exe, tmp, RELOCATED_SUFFIX);
            defer allocator.free(relocated_exe);

            if (std.fs.renameAbsolute(current_exe, relocated_exe)) {
                const tmp_exe = try getTmpExePath(allocator, current_exe, tmp, SELFDELETE_SUFFIX);
                defer allocator.free(tmp_exe);

                try std.fs.copyFileAbsolute(relocated_exe, tmp_exe, .{});
                try spawnTmpExeToDeleteParent(allocator, tmp_exe, relocated_exe);
                return;
            } else |_| {
                // Rename failed, fall through to next strategy
            }
        }
        // Different drive or drive check failed, fall through
    }

    // Strategy 2: Use exclude_path parent if provided
    if (exclude_path) |path| {
        const parent = std.fs.path.dirname(path) orelse return error.NoParentForExcludePath;

        // Check if parent is on the same drive as current_exe
        const exe_drive = getDriveLetter(current_exe);
        const parent_drive = getDriveLetter(parent);

        // Only try rename if on same drive, otherwise go straight to copy
        const can_rename = exe_drive != null and parent_drive != null and exe_drive.? == parent_drive.?;

        const tmp_exe = try getTmpExePath(allocator, current_exe, parent, SELFDELETE_SUFFIX);
        defer allocator.free(tmp_exe);

        if (can_rename) {
            const relocated_exe = try getTmpExePath(allocator, current_exe, parent, RELOCATED_SUFFIX);
            defer allocator.free(relocated_exe);

            if (std.fs.renameAbsolute(current_exe, relocated_exe)) {
                try std.fs.copyFileAbsolute(relocated_exe, tmp_exe, .{});
                try spawnTmpExeToDeleteParent(allocator, tmp_exe, relocated_exe);
                return;
            } else |_| {
                // Rename failed despite same drive, fall through to copy
            }
        }

        // Different drive or rename failed - use copy approach
        try std.fs.copyFileAbsolute(current_exe, tmp_exe, .{});
        try spawnTmpExeToDeleteParent(allocator, tmp_exe, current_exe);
        return;
    }

    // Strategy 3: Use exe's own directory (fallback, always same drive)
    const exe_base_dir = std.fs.path.dirname(current_exe) orelse error.UnexpectedNoParentDir;

    const relocated_exe = try getTmpExePath(allocator, current_exe, exe_base_dir, RELOCATED_SUFFIX);
    defer allocator.free(relocated_exe);

    const tmp_exe = try getTmpExePath(allocator, current_exe, exe_base_dir, SELFDELETE_SUFFIX);
    defer allocator.free(tmp_exe);

    // Try to rename in same directory (should always work on same drive)
    if (std.fs.renameAbsolute(current_exe, relocated_exe)) {
        try std.fs.copyFileAbsolute(relocated_exe, tmp_exe, .{});
        try spawnTmpExeToDeleteParent(allocator, tmp_exe, relocated_exe);
        return;
    } else |_| {
        // Rename failed, try copy approach
        try std.fs.copyFileAbsolute(current_exe, tmp_exe, .{});
        try spawnTmpExeToDeleteParent(allocator, tmp_exe, current_exe);
        return;
    }
}

/// Returns the drive letter from an absolute Windows path (e.g., 'C' from "C:\path\to\file")
/// Returns null if the path doesn't start with a drive letter.
fn getDriveLetter(path: []const u8) ?u8 {
    if (path.len < 2) return null;
    if (path[1] != ':') return null;
    const drive = path[0];
    // Normalize to uppercase
    if (drive >= 'a' and drive <= 'z') {
        return drive - ('a' - 'A');
    }
    if (drive >= 'A' and drive <= 'Z') {
        return drive;
    }
    return null;
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

    // Generate 5 random lowercase letters
    const lowercase = "abcdefghijklmnopqrstuvwxyz";
    for (0..5) |_| {
        const idx = random.intRangeAtMost(usize, 0, lowercase.len - 1);
        try temp_name.append(allocator, lowercase[idx]);
    }

    try temp_name.appendSlice(allocator, suffix);

    return std.fs.path.join(allocator, &.{ base_dir, temp_name.items });
}

/// Spawns the temporary exe and instructs it to delete the parent exe.
/// The child will wait until the parent process exits, then delete the target file.
fn spawnTmpExeToDeleteParent(
    allocator: std.mem.Allocator,
    tmp_exe: []const u8,
    original_exe: []const u8,
) !void {
    const tmp_exe_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, tmp_exe);
    defer allocator.free(tmp_exe_w);

    // Open the temp exe with FILE_FLAG_DELETE_ON_CLOSE so it gets deleted when all handles close
    const GENERIC_READ: windows.DWORD = 0x80000000;
    const FILE_SHARE_READ: windows.DWORD = 0x00000001;
    const FILE_SHARE_DELETE: windows.DWORD = 0x00000004;
    const OPEN_EXISTING: windows.DWORD = 3;
    const FILE_FLAG_DELETE_ON_CLOSE: windows.DWORD = 0x04000000;

    var sa = windows.SECURITY_ATTRIBUTES{
        .nLength = @sizeOf(windows.SECURITY_ATTRIBUTES),
        .lpSecurityDescriptor = null,
        .bInheritHandle = windows.TRUE,
    };

    const tmp_handle = windows.kernel32.CreateFileW(
        tmp_exe_w.ptr,
        GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_DELETE,
        @ptrCast(&sa),
        OPEN_EXISTING,
        FILE_FLAG_DELETE_ON_CLOSE,
        null,
    );

    if (tmp_handle == windows.INVALID_HANDLE_VALUE) {
        return error.CannotOpenTempExe;
    }
    errdefer windows.CloseHandle(tmp_handle);

    // Duplicate the current process handle so the child can wait on it
    const DUPLICATE_SAME_ACCESS: windows.DWORD = 0x00000002;
    var process_handle: windows.HANDLE = undefined;

    const current_process = windows.kernel32.GetCurrentProcess();
    if (windows.kernel32.DuplicateHandle(
        current_process,
        current_process,
        current_process,
        &process_handle,
        0,
        windows.TRUE,
        DUPLICATE_SAME_ACCESS,
    ) == 0) {
        windows.CloseHandle(tmp_handle);
        return error.CannotDuplicateHandle;
    }
    errdefer windows.CloseHandle(process_handle);

    // Spawn the temp exe with arguments: <process_handle> <original_exe_path>
    // We must use CreateProcessW directly to ensure handle inheritance
    const process_handle_str = try std.fmt.allocPrint(allocator, "{d}", .{@intFromPtr(process_handle)});
    defer allocator.free(process_handle_str);

    // Build command line: "tmp_exe process_handle original_exe"
    const cmdline = try std.fmt.allocPrint(allocator, "\"{s}\" {s} \"{s}\"", .{ tmp_exe, process_handle_str, original_exe });
    defer allocator.free(cmdline);

    const cmdline_w = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, cmdline);
    defer allocator.free(cmdline_w);

    var si: windows.STARTUPINFOW = std.mem.zeroes(windows.STARTUPINFOW);
    si.cb = @sizeOf(windows.STARTUPINFOW);

    var pi: windows.PROCESS_INFORMATION = undefined;

    const result = windows.kernel32.CreateProcessW(
        null,
        @ptrCast(cmdline_w.ptr),
        null,
        null,
        windows.TRUE,
        @bitCast(@as(u32, 0)),
        null,
        null,
        &si,
        &pi,
    );

    if (result == 0) {
        windows.CloseHandle(process_handle);
        windows.CloseHandle(tmp_handle);
        return error.CannotSpawnTempExe;
    }

    // Close the process/thread handles we don't need
    windows.CloseHandle(pi.hProcess);
    windows.CloseHandle(pi.hThread);

    // Give the child process time to inherit the handles before we close them
    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Now close our handles - the child has inherited them
    windows.CloseHandle(process_handle);
    windows.CloseHandle(tmp_handle);
}

/// This function is called when the process detects it's running as a self-delete helper.
/// It waits for the parent process to exit, then deletes the original executable.
fn performSelfDeleteCleanup(_allocator: ?std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = if (_allocator) |a| a else arena.allocator();

    // Get command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        return error.InvalidSelfDeleteArgs;
    }

    // Parse the parent process handle
    const parent_handle_int = try std.fmt.parseInt(usize, args[1], 10);
    const parent_handle: windows.HANDLE = @ptrFromInt(parent_handle_int);
    defer windows.CloseHandle(parent_handle);

    const file_to_delete = args[2];

    // Wait for parent process to exit
    const wait_result = windows.kernel32.WaitForSingleObject(parent_handle, windows.INFINITE);
    if (wait_result != windows.WAIT_OBJECT_0) {
        return error.WaitFailed;
    }

    // Delete the original executable
    try std.fs.deleteFileAbsolute(file_to_delete);

    // Spawn a dummy process to trigger DELETE_ON_CLOSE for our own executable
    // We use cmd.exe with a small delay so it outlives this process
    // We must use CreateProcessW directly to ensure handle inheritance
    var si: windows.STARTUPINFOW = std.mem.zeroes(windows.STARTUPINFOW);
    si.cb = @sizeOf(windows.STARTUPINFOW);

    var pi: windows.PROCESS_INFORMATION = undefined;

    // CreateProcessW wants a mutable wide-character command line
    var cmdline_w = [_]u16{0} ** 256;
    const cmd = std.unicode.utf8ToUtf16LeStringLiteral("cmd.exe /c exit");
    @memcpy(cmdline_w[0..cmd.len], cmd);
    cmdline_w[cmd.len] = 0;

    // bInheritHandles = TRUE is critical for inheriting the DELETE_ON_CLOSE handle
    const result = windows.kernel32.CreateProcessW(
        null,
        @ptrCast(&cmdline_w),
        null,
        null,
        windows.TRUE, // bInheritHandles
        @bitCast(@as(u32, 0x08000000)), // CREATE_NO_WINDOW
        null,
        null,
        &si,
        &pi,
    );

    // Spawn and exit immediately
    // The cmd.exe process will inherit the DELETE_ON_CLOSE handle and trigger deletion when it exits
    _ = result;
}
