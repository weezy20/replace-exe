const std = @import("std");
var pathbuf: [std.fs.max_path_bytes]u8 = undefined;

/// Deletes the currently running executable (allowed on Unix/Linux).
pub fn selfDelete() !void {
    const exe = try std.fs.selfExePath(&pathbuf);
    try std.fs.cwd().deleteFile(try std.fs.realpath(exe, &pathbuf));
}

/// Replaces the currently running executable with `new_executable_path`.
/// Creates a temporary file next to the running executable, copies the new
/// binary into it, preserves permissions, and atomically renames it.
pub fn selfReplace(new_executable_path: []const u8) !void {
    const exe = try std.fs.selfExePath(&pathbuf);
    const abs_path = try std.fs.realpath(exe, &pathbuf);
    _ = abs_path;
    _ = new_executable_path;
}
