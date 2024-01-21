const std = @import("std");
const Allocator = std.mem.Allocator;

const Lexer = @import("./Lexer.zig");

const Field = @import("./field.zig").Field;

const Self = @This();

fields: []Field,
allocator: Allocator,

pub fn init(allocator: Allocator, config: []const u8) !Self {
    var fields = std.ArrayList(Field).init(allocator);
    defer fields.deinit();
    errdefer {
        for (fields.items) |field| {
            field.deinit(allocator);
        }
    }

    var lexer: Lexer = .{ .buf = config, .allocator = allocator };
    try lexer.consume('{');

    while (lexer.good()) {
        const item = try lexer.nextField();
        try fields.append(item);
    }
    try lexer.consume('}');
    const f = try allocator.dupe(Field, fields.items);

    return .{ .fields = f, .allocator = allocator };
}

pub fn deinit(self: *Self) void {
    for (self.fields) |*field| {
        field.deinit(self.allocator);
    }
    self.allocator.free(self.fields);
}
