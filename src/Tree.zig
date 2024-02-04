const std = @import("std");
const Allocator = std.mem.Allocator;

const Lexer = @import("./Lexer.zig");
const Parser = @import("Parser.zig");

const Field = @import("./field.zig").Field;
const Value = @import("./field.zig").Value;

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

pub fn deinit(self: *Self) void {
    self.value.deinit(self.allocator);
    self.allocator.destroy(self.value);
}
