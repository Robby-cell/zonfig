const std = @import("std");

const Tree = @import("./root.zig").Tree;
const Parser = @import("Parser.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tree = try Tree.init(allocator,
    // \\{
    // \\  foo = "Hello world",
    // \\  bar = 455,
    // \\  baz = 445.333,
    // \\  biz = {
    // \\      foo2 = 44,
    // \\  },
    // \\  bez = [
    // \\      455,
    // \\      44,
    // \\      2211,
    // \\      "Hello",
    // \\  ],
    // \\}
        \\[
        \\  45,
        \\  "44",
        \\  {
        \\      key = "value",
        \\  },
        \\  { },
        \\  [],
        \\]
    );
    defer tree.deinit();
    // var iter = tree.fields.@"struct".fields.iterator();
    //
    // while (iter.next()) |pair|
    //     std.debug.print("{s} = {any}\n", .{ pair.key_ptr.*, pair.value_ptr.* });

    for (tree.fields.array.inners.items) |val| {
        std.debug.print("{any}\n", .{val});
    }

    var parser = Parser.init("{ item = 45, }", allocator);
    const value = try parser.nextValue();
    defer {
        value.deinit(allocator);
        allocator.destroy(value);
    }

    std.debug.print("WITH PARSER: {any}\n", .{value.field("item").?.int});
}
