const std = @import("std");

const Self = @This();

position: Position,
type: TokenType,

pub const TokenType = enum {
    string,
    int,
    float,

    ident,

    left_bracket,
    right_bracket,
    left_curly,
    right_curly,

    eq,
    comma,

    @"error",
};

pub const Position = struct {
    start: usize,
    end: usize,
    line: usize,

    pub fn init(start: usize, end: usize, line: usize) Position {
        return .{
            .start = start,
            .end = end,
            .line = line,
        };
    }
};

pub fn init(token_type: TokenType, position: Position) Self {
    return .{
        .type = token_type,
        .position = position,
    };
}

pub fn write(self: *const Self, writer: anytype, buffer: []const u8) anyerror!void {
    switch (self.type) {
        .eq => try writer.print("=", .{}),
        .comma => try writer.print(",", .{}),
        .string, .int, .float, .ident => try writer.print("{s}", .{buffer[self.position.start..self.position.end]}),
        else => |b| try writer.print("{c}", .{switch (b) {
            .left_bracket => '[',
            .right_bracket => ']',
            .left_curly => '{',
            .right_curly => '}',
            else => unreachable,
        }}),
    }
}
