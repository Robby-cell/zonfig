const std = @import("std");

const Tree = @import("./root.zig").Tree;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tree = try Tree.init(allocator, "hello= 34.5556,value=344,");
    defer tree.deinit();

    std.debug.print("{any}\n", .{tree.fields});
}
