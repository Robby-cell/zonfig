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
    );
    defer tree.deinit();

    std.debug.print("{any}\n", .{tree.fields});

    std.debug.print("LAST ELEMENT ENTRIES:\n", .{});
    for (tree.fields[tree.fields.len - 1].value.array) |value|
        std.debug.print("{any}\n", .{value});
}
