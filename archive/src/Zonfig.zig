const std = @import("std");
const Allocator = std.mem.Allocator;

const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");

const Field = value.Field;
const Value = value.Value;

pub const value = @import("field.zig");

const Self = @This();

value: *Value,
allocator: Allocator,

pub fn init(allocator: Allocator, config: []const u8) !Self {
    var parser = Parser.init(config, allocator);
    const f = try parser.nextValue();

    return .{ .value = f, .allocator = allocator };
}

pub fn field(self: *const Self, field_name: []const u8) ?*Value {
    return self.value.field(field_name);
}

pub fn at(self: *const Self, index: usize) ?*Value {
    return self.value.at(index);
}

pub fn deinit(self: *const Self) void {
    self.value.deinit(self.allocator);
    self.allocator.destroy(self.value);
}

pub fn print(self: *const Self) !void {
    const writer = std.io.getStdOut().writer();
    try self.value.write(writer, 0);
}
