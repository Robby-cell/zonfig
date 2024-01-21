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

pub fn good(self: *const Self) bool {
    return self.index < self.buf.len;
}

pub fn nextField(self: *Self) !Field {
    const field_ident = try self.consumeIdent();

    self.consumeWhitespace();
    try self.consume('=');

    const value = try self.consumeValue();
    errdefer value.deinit(self.allocator);

    try self.consume(',');

    const ptr = try self.allocator.create(Value);
    ptr.* = value;
    return .{ .name = field_ident, .value = ptr };
}

fn consumeValue(self: *Self) anyerror!Value {
    self.consumeWhitespace();

    return switch (self.peek(0)) {
        '0'...'9' => try self.consumeNumber(),
        '"' => try self.consumeString(),
        '{' => try self.consumeStruct(),
        '[' => try self.consumeArray(),

        else => error.UnexpectedToken,
    };
}

fn consumeArray(self: *Self) anyerror!Value {
    _ = self;
    @panic("Unimplemented");
}

fn consumeStruct(self: *Self) !Value {
    try self.consume('{');

    self.consumeWhitespace();
    var fields = std.ArrayList(Struct.StructField).init(self.allocator);
    errdefer {
        for (fields.items) |*item| {
            item.deinit(self.allocator);
        }
        fields.deinit();
    }

    while (self.peek(0) != '}') {
        const name = try self.consumeIdent();

        self.consumeWhitespace();
        try self.consume('=');

        self.consumeWhitespace();
        const value = try self.consumeValue();

        try self.consume(',');

        const ptr = try self.allocator.create(Value);
        ptr.* = value;
        const field: Struct.StructField = .{ .name = name, .value = ptr };
        try fields.append(field);

        self.consumeWhitespace();
    }

    return .{ .@"struct" = .{ .fields = fields.items } };
}

fn consumeString(self: *Self) !Value {
    const start = self.index;

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
    return .{ .string = try self.allocator.dupe(u8, self.buf[start..self.index]) };
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
        else => error.UnexpectedToken,
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
fn consume(self: *Self, expected: u8) !void {
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
