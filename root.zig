const std = @import("std");
const builtin = @import("builtin");

// Conditionally import platform-specific implementations
const impl = switch (builtin.os.tag) {
    .linux, .macos, .freebsd, .openbsd, .netbsd, .dragonfly => @import("unix.zig"),
    .windows => @import("windows.zig"),
    else => @compileError("Unsupported operating system"),
};
/// Replaces the current executable with a file provided at `new_exe_path`.
/// Can be used to update to a newer version of a running executable or something else entirely.
pub fn selfReplace(allocator: std.mem.Allocator, new_exe_path: []const u8) !void {
    return impl.selfReplace(allocator, new_exe_path);
}
/// Deletes the current executable. On unix this is immediate, but on windows it's deferred unitl current process exits.
/// Can be used as a self-uninstall mechanism. Do not follow this function with a selfReplace call as that will surely fail.
/// On unix/linux you can safely pass a null allocator as it's not needed but provided for API consistency with windows which does require
/// an allocator. If no allocator is provided as on FFI, then an arena allocator will be used.
pub fn selfDelete(allocator: ?std.mem.Allocator) !void {
    return impl.selfDelete(allocator);
}

/// Like `selfDelete` but accepts a path that is not used for temporary file operations.
/// This is equivalent to [`self_delete`] on Unix, but it instructs the deletion logic to
/// not place temporary files in the given path (or any subdirectory of) for the duration
/// of the deletion operation.  This is necessary to demolish folder more complex folder
/// structures on Windows.
pub fn selfDeleteExcludingPath(allocator: ?std.mem.Allocator, exclude_path: []const u8) !void {
    return impl.selfDeleteExcludingPath(allocator, exclude_path);
}
