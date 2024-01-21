const std = @import("std");

const Tree = @import("./root.zig").Tree;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tree = try Tree.init(allocator,
        \\{
        \\  foo = "Hello world",
        \\  bar = 455,
        \\  baz = 445.333,
        \\  biz = {
        \\      foo2 = 44,
        \\  },
        \\  bez = [
        \\      455,
        \\      44,
        \\      2211,
        \\      "Hello",
        \\  ],
        \\}
        // \\[
        // \\  45,
        // \\  "44",
        // \\]
    );
    defer tree.deinit();
    var iter = tree.fields.@"struct".fields.iterator();

    while (iter.next()) |pair|
        std.debug.print("{s} = {any}\n", .{ pair.key_ptr.*, pair.value_ptr.* });
}
