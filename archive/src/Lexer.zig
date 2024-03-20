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

inline fn next(self: *Self) u8 {
    if (self.index >= self.buf.len)
        return 255;

    defer self.index += 1;
    if (self.buf[self.index] == '\n') {
        self.line += 1;
    }
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

fn consumeWhitespace(self: *Self) void {
    while (std.ascii.isWhitespace(self.peek(0))) {
        if (self.peek(0) == '\n') {
            self.line += 1;
        }
        _ = self.next();
    }
    if (self.peek(0) == '#') {
        while (self.peek(0) != '\n') {
            _ = self.next();
        }
        self.consumeWhitespace();
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
