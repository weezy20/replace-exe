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
/// Requires an allocator on all platforms to perform temporary file operations.
/// For C FFI boundaries, a c_allocator will be chosen as default.
pub fn selfReplace(allocator: std.mem.Allocator, new_exe_path: []const u8) !void {
    return impl.selfReplace(allocator, new_exe_path);
}
/// Deletes the current executable. On unix this is immediate, but on windows it's deferred unitl current process exits.
/// Can be used as a self-uninstall mechanism. Do not follow this function with a selfReplace call as that will surely fail.
/// On unix/linux you can safely pass a null allocator as it's not needed but provided for API consistency with windows which does require
/// an allocator. If no allocator is provided, then if it's used on windows will error.NoAllocator.
/// For C FFI boundaries, a c_allocator will be chosen as default.
pub fn selfDelete(allocator: ?std.mem.Allocator) !void {
    return impl.selfDelete(allocator);
}

/// Like `selfDelete` but accepts a path that is not used for temporary file operations.
/// This is equivalent to [`self_delete`] on Unix, but it instructs the deletion logic to
/// not place temporary files in the given path (or any subdirectory of) for the duration
/// of the deletion operation.  This is necessary to demolish folder more complex folder
/// structures on Windows.
///
/// Windows requires an allocator but unix/linux does not.
pub fn selfDeleteExcludingPath(allocator: ?std.mem.Allocator, exclude_path: []const u8) !void {
    return impl.selfDeleteExcludingPath(allocator, exclude_path);
}

/// Call this at the very start of main() on Windows to enable self-deletion hooks.
/// REQUIRED on Windows - selfDelete() and selfReplace() will return error.HooksNotRegistered if not called.
/// Is a no-op on non-Windows platforms.
///
/// This checks if the current process is a deletion helper and handles cleanup accordingly.
/// If it is a helper process, this function will not return (process exits after cleanup).
///
/// Example usage:
/// ```zig
/// pub fn main() !void {
///     const re = @import("replace-exe");
///     re.registerHooks(); // Must be first line on Windows
///
///     // Your normal program logic
///     // ...
///
///     // Later, when you want to self-delete:
///     try re.selfDelete(allocator);
/// }
/// ```
pub fn registerHooks(allocator: ?std.mem.Allocator) void {
    if (builtin.os.tag != .windows) return;
    impl.selfDeleteInit(allocator);
}
