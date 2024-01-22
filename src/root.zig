const std = @import("std");

pub const Tree = @import("./Tree.zig");

test "from file" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;
    const eql = std.mem.eql;

    const contents = blk: {
        const file = try std.fs.cwd().openFile("config.zf", .{ .mode = .read_only });
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 4096);
        break :blk contents;
    };
    // defer allocator.free(contents);

    var tree = try Tree.init(allocator, contents);
    defer tree.deinit();
    allocator.free(contents);

    try expect(eql(u8, "zonfig", tree.field("name").?.string));
    try expect(eql(u8, "0.1.0", tree.field("version").?.string));
    try expect(eql(u8, "src/field.zig", tree.field("files").?.at(0).?.string));
    try expect(eql(u8, "run", tree.field("cmd").?.field("run").?.string));
}

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

    try expect(tree.field("foo").?.int == 67);
    try expect(tree.field("bar").?.at(1).?.int == 34);
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
        try expect(tree.at(i).?.int == i + 1);
    }
    try expect(tree.at(3).?.field("foo").?.int == 4);
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
    , tree.field("foo").?.string));
}
