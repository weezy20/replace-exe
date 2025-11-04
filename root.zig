const std = @import("std");
const builtin = @import("builtin");

// Conditionally import platform-specific implementations
const impl = switch (builtin.os.tag) {
    .linux, .macos, .freebsd, .openbsd, .netbsd, .dragonfly => @import("unix.zig"),
    .windows => @import("windows.zig"),
    else => @compileError("Unsupported operating system"),
};

pub fn selfReplace(new_exe_path: []const u8) !void {
    return impl.selfReplace(new_exe_path);
}

pub fn selfDelete() !void {
    return impl.selfDelete();
}
