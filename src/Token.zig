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
};

pub const Position = struct {
    start: usize,
    end: usize,
    line: usize,
};
