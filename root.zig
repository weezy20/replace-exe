const std = @import("std");

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "add works" {
    const result = add(2, 3);
    try std.testing.expectEqual(@as(i32, 5), result);
}
