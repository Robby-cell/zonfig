const std = @import("std");

const Tree = @import("./root.zig").Tree;
const Parser = @import("Parser.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tree = try Tree.init(allocator,
        \\{
        \\  value = 56.33,
        \\  string = "hello world",
        \\  array = [
        \\      3,
        \\      66,
        \\      11,
        \\  ],
        \\  struct = {
        \\      key = [ 22 ]
        \\  }
        \\}
    );
    defer tree.deinit();
    const writer = std.io.getStdOut().writer();

    try tree.value.write(writer, 0);

    // try value.write(writer, 0);

    // std.debug.print("WITH PARSER: {any}\n", .{value.*});
}
