const std = @import("std");
const Allocator = std.mem.Allocator;

const Lexer = @import("./Lexer.zig");

const Field = @import("./field.zig").Field;
const Value = @import("./field.zig").Value;

const Self = @This();

const TreeValue = union(enum) {
    s: []Field,
    a: []*Value,
};
fields: TreeValue,
allocator: Allocator,

pub fn init(allocator: Allocator, config: []const u8) !Self {
    var lexer: Lexer = .{ .buf = config, .allocator = allocator };

    const f: TreeValue = switch (lexer.buf[0]) {
        '{' => blk: {
            var fields = std.ArrayList(Field).init(allocator);
            defer fields.deinit();
            errdefer {
                for (fields.items) |*field| {
                    field.deinit(allocator);
                }
            }

            try lexer.consume('{');

            while (lexer.good()) {
                const item = try lexer.nextField();
                errdefer {
                    item.deinit(allocator);
                }

                try fields.append(item);
            }
            try lexer.consume('}');
            const f = try allocator.dupe(Field, fields.items);
            break :blk .{ .s = f };
        },
        '[' => blk: {
            var fields = std.ArrayList(*Value).init(allocator);
            defer fields.deinit();
            errdefer {
                for (fields.items) |f| {
                    f.deinit(allocator);
                    allocator.destroy(f);
                }
            }

            try lexer.consume('[');

            while (lexer.good()) {
                const v = try lexer.consumeValue();
                errdefer {
                    v.deinit(allocator);
                    allocator.destroy(v);
                }
                try lexer.consume(',');
                try fields.append(v);
            }

            try lexer.consume(']');
            const f = try allocator.dupe(*Value, fields.items);
            break :blk .{ .a = f };
        },

        else => return error.UnexpectedToken,
    };

    return .{ .fields = f, .allocator = allocator };
}

pub fn deinit(self: *Self) void {
    switch (self.fields) {
        .s => |fields| {
            for (fields) |*field| {
                field.deinit(self.allocator);
            }
            self.allocator.free(fields);
        },
        .a => |array| {
            for (array) |value| {
                value.deinit(self.allocator);
                self.allocator.destroy(value);
            }
            self.allocator.free(array);
        },
    }
}
