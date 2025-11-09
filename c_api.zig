const re = @import("replace_exe");
const std = @import("std");
const native_os = @import("builtin").os.tag;

// Export a C-callable version of selfDelete
export fn self_delete() c_int {
    const allocator = std.heap.c_allocator;
    re.selfDelete(allocator) catch {
        return -1;
    };
    return 0;
}

// Export a C-callable version of selfReplace
export fn self_replace(new_exe_path: [*c]const u8) c_int {
    const allocator = std.heap.c_allocator;

    // Convert C string to Zig slice (null-terminated expected)
    const path = std.mem.sliceTo(new_exe_path, 0);

    re.selfReplace(allocator, path) catch {
        return -1;
    };
    return 0;
}

// Export a C-callable version of selfDeleteExcludingPath
export fn self_delete_excluding_path(exclude_path: [*c]const u8) c_int {

    // Convert C string to Zig slice (null-terminated expected)
    const path = std.mem.sliceTo(exclude_path, 0);

    re.selfDeleteExcludingPath(switch (native_os) {
        .windows => std.heap.c_allocator,
        else => null,
    }, path) catch {
        return -1;
    };
    return 0;
}

/// Windows only, is a no-op on linux/unix
export fn register_hooks() c_int {
    switch (native_os) {
        .windows => re.registerHooks(),
        else => {},
    }
    return 0;
}
