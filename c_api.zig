const re = @import("replace_exe");
const std = @import("std");

// Export a C-callable version of selfDelete
export fn re_self_delete() c_int {
    const allocator = std.heap.c_allocator;
    re.selfDelete(allocator) catch {
        return -1;
    };
    return 0;
}

// Export a C-callable version of selfReplace
export fn re_self_replace(new_exe_path: [*c]const u8) c_int {
    const allocator = std.heap.c_allocator;

    // Convert C string to Zig slice (null-terminated expected)
    const path = std.mem.sliceTo(new_exe_path, 0);

    re.selfReplace(allocator, path) catch {
        return -1;
    };
    return 0;
}
