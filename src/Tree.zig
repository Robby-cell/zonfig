const std = @import("std");
const Allocator = std.mem.Allocator;

const Lexer = @import("./Lexer.zig");

const Field = @import("./field.zig").Field;
const Value = @import("./field.zig").Value;

const Self = @This();

fields: *Value,
allocator: Allocator,

pub fn init(allocator: Allocator, config: []const u8) !Self {
    var lexer: Lexer = .{ .buf = config, .allocator = allocator };
    const f = try lexer.consumeValue();

    return .{ .fields = f, .allocator = allocator };
}

pub fn field(self: *const Self, field_name: []const u8) ?*Value {
    return self.fields.field(field_name);
}

pub fn at(self: *const Self, index: usize) ?*Value {
    return self.fields.at(index);
}

pub fn deinit(self: *Self) void {
    self.fields.deinit(self.allocator);
    self.allocator.destroy(self.fields);
}
