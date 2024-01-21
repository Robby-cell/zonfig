const std = @import("std");
const Allocator = std.mem.Allocator;

const Field = @import("./field.zig").Field;
const Value = @import("./field.zig").Value;
const Struct = @import("./field.zig").Struct;

const Self = @This();

buf: []const u8,
index: usize = 0,
allocator: Allocator,

fn next(self: *Self) u8 {
    if (self.index >= self.buf.len)
        return 255;

    defer self.index += 1;
    return self.buf[self.index];
}

pub inline fn good(self: *Self) bool {
    self.consumeWhitespace();
    return self.index < self.buf.len and self.peek(0) != '}' and self.peek(0) != ']';
}

pub fn nextField(self: *Self) !Field {
    const field_ident = try self.consumeIdent();

    self.consumeWhitespace();
    try self.consume('=');

    const value = try self.consumeValue();
    errdefer {
        value.deinit(self.allocator);
        self.allocator.destroy(value);
    }

    try self.consume(',');

    return .{ .name = field_ident, .value = value };
}

pub fn consumeValue(self: *Self) anyerror!*Value {
    self.consumeWhitespace();

    const ptr = try self.allocator.create(Value);
    errdefer self.allocator.destroy(ptr);

    ptr.* = switch (self.peek(0)) {
        '0'...'9' => try self.consumeNumber(),
        '"' => try self.consumeString(),
        '{' => try self.consumeStruct(),
        '[' => try self.consumeArray(),

        else => |c| {
            std.log.warn("Found {c} at {d}\n", .{ c, self.index });
            return error.UnexpectedToken;
        },
    };

    return ptr;
}

fn consumeArray(self: *Self) anyerror!Value {
    try self.consume('[');
    self.consumeWhitespace();

    var arr = std.ArrayList(*Value).init(self.allocator);
    defer {
        arr.deinit();
    }
    errdefer {
        for (arr.items) |value| {
            value.deinit(self.allocator);
            self.allocator.destroy(value);
        }
    }

    while (self.peek(0) != ']') {
        const value = try self.consumeValue();
        errdefer {
            value.deinit(self.allocator);
            self.allocator.destroy(value);
        }

        self.consumeWhitespace();
        try self.consume(',');

        try arr.append(value);
        self.consumeWhitespace();
    }
    try self.consume(']');

    const items = try self.allocator.dupe(*Value, arr.items);

    return Value.arrayValue(items);
}

fn consumeStruct(self: *Self) !Value {
    try self.consume('{');

    self.consumeWhitespace();
    var fields = std.ArrayList(Struct.StructField).init(self.allocator);
    defer fields.deinit();
    errdefer {
        for (fields.items) |*item| {
            item.deinit(self.allocator);
        }
    }

    while (self.peek(0) != '}') {
        const name = try self.consumeIdent();

        self.consumeWhitespace();
        try self.consume('=');

        const value = try self.consumeValue();
        errdefer {
            value.deinit(self.allocator);
            self.allocator.destroy(value);
        }

        self.consumeWhitespace();
        try self.consume(',');

        const field: Struct.StructField = .{ .name = name, .value = value };
        try fields.append(field);

        self.consumeWhitespace();
    }
    try self.consume('}');

    const f = try self.allocator.dupe(Struct.StructField, fields.items);
    const s = Struct.init(f);

    return Value.structValue(s);
}

fn consumeString(self: *Self) !Value {
    const start = self.index;
    try self.consume('"');

    var state: enum { normal, escaped, end } = .normal;
    while (state != .end) {
        switch (state) {
            .normal => switch (self.peek(0)) {
                '"' => {
                    try self.consume('"');
                    state = .end;
                },
                '\\' => {
                    try self.consume('\\');
                    state = .escaped;
                },
                else => _ = self.next(),
            },
            .escaped => {
                switch (self.peek(0)) {
                    't', 'n', '\\', '"', '\'' => |ch| {
                        try self.consume(ch);
                        state = .normal;
                    },
                    else => return error.UnexpectedToken,
                }
            },
            else => unreachable,
        }
    }
    const s = try self.allocator.dupe(u8, self.buf[start..self.index]);
    return Value.stringValue(s);
}

fn consumeNumber(self: *Self) !Value {
    var state: enum { int, float } = .int;
    const start = self.index;

    while (true) {
        switch (self.peek(0)) {
            '0'...'9' => _ = self.next(),
            '.' => {
                if (state == .int) {
                    state = .float;
                    try self.consume('.');
                } else return error.UnexpectedToken;
            },

            else => break,
        }
    }

    return if (state == .int) .{
        .int = std.fmt.parseInt(i64, self.buf[start..self.index], 10) catch unreachable,
    } else .{
        .float = std.fmt.parseFloat(f64, self.buf[start..self.index]) catch unreachable,
    };
}

fn consumeIdent(self: *Self) ![]const u8 {
    self.consumeWhitespace();

    return switch (self.peek(0)) {
        'a'...'z', 'A'...'Z', '_' => blk: {
            const start = self.index;

            while (std.ascii.isAlphanumeric(self.peek(0)) or self.peek(0) == '_') {
                _ = self.next();
            }

            break :blk self.buf[start..self.index];
        },
        else => |c| blk: {
            std.log.warn("Expected {c} but found {c}, {d}\n", .{ '.', c, self.index });
            break :blk error.UnexpectedToken;
        },
    };
}

fn consumeWhitespace(self: *Self) void {
    while (std.ascii.isWhitespace(self.peek(0))) {
        if (self.peek(0) == '\n') {
            // new line
        }
        _ = self.next();
    }
}

/// Consume the expected character or return error if its not found
pub fn consume(self: *Self, expected: u8) !void {
    if (self.peek(0) != expected) {
        std.log.warn("Expected {c} but found {c}\n", .{ expected, self.peek(0) });
        return error.UnexpectedToken;
    }
    _ = self.next();
}

fn peek(self: *const Self, peek_distance: usize) u8 {
    if (self.index + peek_distance >= self.buf.len)
        return 255;

    return self.buf[self.index + peek_distance];
}
