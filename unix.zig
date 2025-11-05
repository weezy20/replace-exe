const std = @import("std");

/// Deletes the currently running executable (allowed on Unix/Linux).
pub fn selfDelete() !void {
    var pathbuf: [std.fs.max_path_bytes]u8 = undefined;
    const exe = try std.fs.selfExePath(&pathbuf);
    try std.posix.unlink(try std.fs.realpath(exe, &pathbuf));
}

/// Replaces the currently running executable with `new_executable_path`.
/// Creates a temporary file next to the running executable, copies the new
/// binary into it, preserves permissions, and atomically renames it.
pub fn selfReplace(allocator: std.mem.Allocator, new_executable_path: []const u8) !void {
    const current_exe = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(current_exe);
    const new_exe_abs = try std.fs.realpathAlloc(allocator, new_executable_path);
    defer allocator.free(new_exe_abs);
    const abs_path = try std.fs.realpathAlloc(allocator, current_exe);
    defer allocator.free(abs_path);
    const stat = std.fs.cwd().statFile(abs_path) catch |err| switch (err) {
        error.FileNotFound => {
            // On some systems, selfExePath might return a path that no longer exists
            // if the executable was already moved/deleted
            return error.FileNotFound;
        },
        else => {
            return err;
        },
    };
    const old_mode = stat.mode;
    const parent_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(parent_dir_path);

    const exe_basename = std.fs.path.basename(current_exe);
    const temp_name = try std.fmt.allocPrint(
        allocator,
        ".{s}.__temp__{d}",
        .{ exe_basename, std.time.timestamp() },
    );
    defer allocator.free(temp_name);

    const temp_path = try std.fs.path.join(allocator, &.{ parent_dir_path, temp_name });
    defer allocator.free(temp_path);

    std.fs.copyFileAbsolute(new_exe_abs, temp_path, .{}) catch |err| {
        return err;
    };
    errdefer std.fs.deleteFileAbsolute(temp_path) catch {};
    // Apply old permissions to the new file
    const temp_file = try std.fs.openFileAbsolute(temp_path, .{});
    defer temp_file.close();
    try temp_file.chmod(old_mode);
    // Atomic rename of the temporary file to the actual executable path
    try std.posix.rename(temp_path, abs_path);
}
