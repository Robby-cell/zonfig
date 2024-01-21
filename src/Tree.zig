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

    // const f: TreeValue = switch (lexer.buf[0]) {
    //     '{' => blk: {
    //         var fields = std.StringHashMap(*Value).init(allocator);
    //         errdefer fields.deinit();
    //         errdefer {
    //             var iter = fields.iterator();
    //             while (iter.next()) |*field| {
    //                 field.value_ptr.*.deinit(allocator);
    //             }
    //         }
    //
    //         try lexer.desire('{');
    //
    //         while (lexer.good()) {
    //             const item = try lexer.nextField();
    //             errdefer {
    //                 item.deinit(allocator);
    //             }
    //
    //             // try fields.append(item);
    //             try fields.put(item.name, item.value);
    //         }
    //         try lexer.desire('}');
    //         // const f = try allocator.dupe(Field, fields.items);
    //         break :blk .{ .s = fields };
    //     },
    //     '[' => blk: {
    //         var fields = std.ArrayList(*Value).init(allocator);
    //         defer fields.deinit();
    //         errdefer {
    //             for (fields.items) |f| {
    //                 f.deinit(allocator);
    //                 // allocator.destroy(f);
    //             }
    //         }
    //
    //         try lexer.desire('[');
    //
    //         while (lexer.good()) {
    //             const v = try lexer.consumeValue();
    //             errdefer {
    //                 v.deinit(allocator);
    //                 allocator.destroy(v);
    //             }
    //             try lexer.consume(',');
    //             try fields.append(v);
    //         }
    //
    //         try lexer.desire(']');
    //         // const f = try allocator.dupe(*Value, fields.items);
    //         break :blk .{ .a = fields };
    //     },
    //
    //     else => return error.UnexpectedToken,
    // };
    const f = try lexer.consumeValue();

    return .{ .fields = f, .allocator = allocator };
}

pub fn deinit(self: *Self) void {
    // switch (self.fields) {
    //     .s => |*fields| {
    //         var iter = fields.iterator();
    //         while (iter.next()) |field| {
    //             field.value_ptr.*.deinit(self.allocator);
    //             self.allocator.destroy(field.value_ptr.*);
    //         }
    //         fields.deinit();
    //     },
    //     .a => |*array| {
    //         for (array.items) |value| {
    //             value.deinit(self.allocator);
    //             self.allocator.destroy(value);
    //         }
    //         // self.allocator.free(array);
    //         array.deinit();
    //     },
    // }
    self.fields.deinit(self.allocator);
    self.allocator.destroy(self.fields);
}
