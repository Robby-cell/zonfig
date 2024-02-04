const std = @import("std");
const Allocator = std.mem.Allocator;

const Field = @import("./field.zig").Field;
const Value = @import("./field.zig").Value;
const Struct = @import("./field.zig").Struct;
const Array = @import("./field.zig").Array;

const Token = @import("Token.zig");
const TokenType = Token.TokenType;
const Position = Token.Position;

const Self = @This();

buf: []const u8,
index: usize = 0,
line: usize = 1,
/// start of this token's position
current: struct { index: usize, line: usize } = undefined,
allocator: Allocator,

inline fn next(self: *Self) u8 {
    if (self.index >= self.buf.len)
        return 255;

    defer self.index += 1;
    return self.buf[self.index];
}

pub fn nextToken(self: *Self) Token {
    self.consumeWhitespace();
    self.current = .{ .index = self.index, .line = self.line };
    return switch (self.peek(0)) {
        'a'...'z', 'A'...'Z', '_' => self.ident(),
        '0'...'9' => self.number(),
        '"' => self.string(),
        else => |c| blk: {
            defer _ = self.next();
            break :blk .{
                .position = .{
                    .start = self.current.index,
                    .end = self.current.index + 1,
                    .line = self.current.line,
                },
                .type = switch (c) {
                    '[' => .left_bracket,
                    ']' => .right_bracket,
                    '{' => .left_curly,
                    '}' => .right_curly,
                    '=' => .eq,
                    ',' => .comma,
                    else => .@"error",
                },
            };
        },
    };
}

fn string(self: *Self) Token {
    _ = self.next();
    while (self.peek(0) != '"') {
        switch (self.peek(0)) {
            0, 255 => return Token{
                .position = .{
                    .start = self.current.index,
                    .end = self.index,
                    .line = self.current.line,
                },
                .type = .@"error",
            },
            '\\' => _ = self.next(),
            else => {},
        }
        _ = self.next();
    }
    _ = self.next();
    return .{
        .position = .{
            .start = self.current.index,
            .end = self.index,
            .line = self.current.line,
        },
        .type = .string,
    };
}

fn ident(self: *Self) Token {
    while (std.ascii.isAlphanumeric(self.peek(0)) or self.peek(0) == '_') {
        _ = self.next();
    }

    return .{
        .position = .{
            .start = self.current.index,
            .end = self.index,
            .line = self.current.line,
        },
        .type = .ident,
    };
}
fn number(self: *Self) Token {
    var @"type": TokenType = .int;
    while (std.ascii.isDigit(self.peek(0))) {
        _ = self.next();
    }
    if (self.peek(0) == '.') {
        _ = self.next();
        while (std.ascii.isDigit(self.peek(0))) {
            _ = self.next();
        }
        @"type" = .float;
    }
    return .{
        .position = .{
            .start = self.current.index,
            .end = self.index,
            .line = self.current.line,
        },
        .type = @"type",
    };
}

pub inline fn good(self: *Self) bool {
    self.consumeWhitespace();
    return self.index < self.buf.len and self.peek(0) != '}' and self.peek(0) != ']';
}

pub fn nextField(self: *Self) !Field {
    self.consumeWhitespace();

    const field_ident = try self.consumeIdent();

    try self.desire('=');

    const value = try self.consumeValue();
    errdefer {
        value.deinit(self.allocator);
        self.allocator.destroy(value);
    }

    try self.desire(',');

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

fn checkForComment(self: *Self) void {
    if (self.peek(0) == '#') {
        // comment
        while (self.peek(0) != '\n') {
            _ = self.consume(self.peek(0)) catch unreachable;
        }
        self.consumeWhitespace();
    }
}

fn consumeArray(self: *Self) anyerror!Value {
    try self.consume('[');
    self.consumeWhitespace();

    var arr = std.ArrayList(*Value).init(self.allocator);
    errdefer {
        for (arr.items) |value| {
            value.deinit(self.allocator);
            self.allocator.destroy(value);
        }
        arr.deinit();
    }

    while (self.peek(0) != ']') {
        self.checkForComment();
        const value = try self.consumeValue();
        errdefer {
            value.deinit(self.allocator);
            self.allocator.destroy(value);
        }

        try self.desire(',');

        try arr.append(value);

        self.consumeWhitespace();
    }
    try self.consume(']');

    return Value.arrayValue(Array.init(arr));
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
        self.checkForComment();

        const name = try self.consumeIdent();

        try self.desire('=');

        const value = try self.consumeValue();
        errdefer {
            value.deinit(self.allocator);
            self.allocator.destroy(value);
        }

        try self.desire(',');

        const field: Struct.StructField = .{ .name = name, .value = value };
        try fields.append(field);

        self.consumeWhitespace();
    }
    try self.consume('}');

    const s = try Struct.init(self.allocator, fields.items);

    return Value.structValue(s);
}

fn consumeString(self: *Self) !Value {
    // const start = self.index;
    try self.consume('"');
    var list = std.ArrayList(u8).init(self.allocator);
    defer list.deinit();

    var state: enum { normal, escaped, end } = .normal;
    while (state != .end) {
        switch (state) {
            .normal => switch (self.peek(0)) {
                255 => return error.UnterminatedString,
                '"' => {
                    try self.consume('"');
                    state = .end;
                },
                '\\' => {
                    try self.consume('\\');
                    state = .escaped;
                },
                else => try list.append(self.next()),
            },
            .escaped => {
                try list.append(switch (self.peek(0)) {
                    't' => '\t',
                    'n' => '\n',
                    '\\', '"', '\'' => |ch| ch,
                    else => return error.UnexpectedToken,
                });
                _ = self.next();
                state = .normal;
            },
            else => unreachable,
        }
    }
    // const s = try self.allocator.dupe(u8, self.buf[start..self.index]);
    const s = try self.allocator.dupe(u8, list.items);
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

pub fn desire(self: *Self, wants: u8) !void {
    self.consumeWhitespace();
    return self.consume(wants);
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
