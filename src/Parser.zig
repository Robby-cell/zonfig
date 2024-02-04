const std = @import("std");
const Allocator = std.mem.Allocator;

const Lexer = @import("Lexer.zig");
const Token = @import("Token.zig");
const TokenType = Token.TokenType;
const _field = @import("field.zig");
const Value = _field.Value;
const Struct = _field.Struct;

const Self = @This();

lexer: Lexer,
current: ?Token,
allocator: Allocator,

pub fn init(buffer: []const u8, allocator: Allocator) Self {
    return .{
        .lexer = .{ .buf = buffer },
        .current = null,
        .allocator = allocator,
    };
}

pub fn nextValue(self: *Self) !*Value {
    const ptr = try self.allocator.create(Value);
    errdefer {
        ptr.deinit(self.allocator);
        self.allocator.destroy(ptr);
    }

    ptr.* = switch (self.nextToken()) {
        .ident => try self.ident(),

        .string => try self.string(),
        .int => try self.integer(),
        .float => self.float(),

        .left_bracket => self.array(),
        .left_curly => self.@"struct"(),

        else => self.@"error"(),
    };

    return ptr;
}

pub fn nextToken(self: *Self) TokenType {
    const token = self.lexer.nextToken();
    self.current = token;
    return token.type;
}

fn @"struct"(self: *Self) !Value {
    // move past the l paren

    var token = self.nextToken();
    const table = std.StringHashMap(*Value).init(self.allocator);
    errdefer {
        var iter = table.iterator();
        while (iter.next()) |pair| {
            self.allocator.free(pair.key_ptr.*);
            pair.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(pair.value_ptr.*);
        }
        table.deinit();
    }

    while (token != .right_curly) {
        const field = if (token.type == .ident) try self.ident() else return error.ExpectedIdentifier;
        errdefer field.deinit(self.allocator);

        token = self.nextToken();
        if (token != .eq) {
            return error.ExpectedEq;
        }

        const value = try self.nextValue();

        try table.put(field, value);

        token = self.nextToken();
        if (token == .right_curly) {
            break;
        }
        if (token == .comma) {
            token = self.nextToken();
        }
    }
    _ = self.nextToken();

    return Value.structValue(Struct{ .fields = table });
}

fn float(self: *Self) Value {
    const token = self.current.?;
    const number = self.lexer.buf[token.position.start..token.position.end];
    const numerical_value = std.fmt.parseFloat(f64, number) catch unreachable;
    return Value.floatValue(numerical_value);
}

fn integer(self: *Self) !Value {
    const token = self.current.?;
    const number = self.lexer.buf[token.position.start..token.position.end];
    const numerical_value = std.fmt.parseInt(i64, number, 10) catch |err| {
        std.log.warn("{any}\n", .{err});
        return err;
    };
    return Value.intValue(numerical_value);
}

fn string(self: *Self) !Value {
    const token = self.current.?;

    var list = std.ArrayList(u8).init(self.allocator);
    defer list.deinit();

    var position: usize = token.position.start;
    while (position < token.position.end) {
        switch (self.lexer.buf[position]) {
            0 => {},
            '"' => break,
            '\\' => {
                position += 1;
                try list.append(switch (self.lexer.buf[position]) {
                    't' => '\t',
                    'n' => '\n',
                    '\\' => '\\',
                    'r' => '\r',
                    '"' => '"',
                    '\'' => '\'',
                    else => return error.InvalidEscapeSequence,
                });
            },
            else => |c| try list.append(c),
        }
        position += 1;
    }
    return Value.stringValue(try self.allocator.dupe(u8, list.items));
}

pub fn ident(self: *Self) ![]u8 {
    const token = self.current.?;
    const lexeme = self.lexer.buf[token.position.start..token.position.end];

    return self.allocator.dupe(u8, lexeme);
}
