const std = @import("std");
const Allocator = std.mem.Allocator;

const String = []u8;

pub const Field = struct {
    name: []const u8,
    value: *Value,

    pub fn deinit(self: *const Field, allocator: Allocator) void {
        self.value.deinit(allocator);
        allocator.destroy(self.value);
    }
};

pub const Value = union(enum) {
    string: String,
    int: i64,
    float: f64,

    @"struct": Struct,
    array: []*Value,

    pub fn stringValue(str: String) Value {
        return .{
            .string = str,
        };
    }

    pub fn intValue(int: i64) Value {
        return .{
            .int = int,
        };
    }

    pub fn floatValue(float: f64) Value {
        return .{
            .float = float,
        };
    }

    pub fn structValue(s: Struct) Value {
        return .{
            .@"struct" = s,
        };
    }

    pub fn arrayValue(a: []*Value) Value {
        return .{
            .array = a,
        };
    }

    pub fn deinit(self: *const Value, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| {
                allocator.free(s);
            },
            .@"struct" => |s| {
                s.deinit(allocator);
            },
            .array => |a| {
                for (a) |value| {
                    value.deinit(allocator);
                    allocator.destroy(value);
                }
                allocator.free(a);
            },

            else => {},
        }
    }
};

pub const Struct = struct {
    fields: []StructField,

    pub const StructField = struct {
        name: []const u8,
        value: ?*Value,

        pub fn deinit(self: *const @This(), allocator: Allocator) void {
            if (self.value) |value| {
                value.deinit(allocator);
                allocator.destroy(value);
            }
        }
    };

    pub fn init(fields: []StructField) Struct {
        return .{
            .fields = fields,
        };
    }

    pub fn deinit(self: *const Struct, allocator: Allocator) void {
        for (self.fields) |*field| {
            if (field.value) |field_value| {
                field_value.deinit(allocator);
                allocator.destroy(field_value);
            }
        }
        allocator.free(self.fields);
    }
};
