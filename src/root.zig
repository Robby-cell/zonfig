const std = @import("std");

pub const Tree = @import("./Tree.zig");

test "struct tests" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    var tree = try Tree.init(allocator,
        \\{
        \\  foo = 67,
        \\  bar = [ 12, 34, ],
        \\}
    );
    defer tree.deinit();

    try expect(tree.fields.@"struct".at("foo").?.int == 67);
    try expect(tree.fields.@"struct".at("bar").?.array[1].int == 34);
}

test "array tests" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    var tree = try Tree.init(allocator,
        \\[
        \\  1,
        \\  2,
        \\  3,
        \\  {
        \\      foo = 4,
        \\  },
        \\]
    );
    defer tree.deinit();

    for (0..3) |i| {
        try expect(tree.fields.array[i].int == i + 1);
    }
    try expect(tree.fields.array[3].@"struct".at("foo").?.int == 4);
}

test "strings in structs" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    var tree = try Tree.init(allocator,
        \\{
        \\  foo = "Hello world\nnew line",
        \\}
    );
    defer tree.deinit();

    try expect(std.mem.eql(u8,
        \\Hello world
        \\new line
    , tree.fields.@"struct".at("foo").?.string));
}
