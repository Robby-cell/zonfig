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

    pub fn deinit(self: *Value, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| {
                allocator.free(s);
            },
            .@"struct" => |*s| {
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
    fields: std.StringHashMap(*Value),

    pub const StructField = struct {
        name: []const u8,
        value: *Value,

        pub fn deinit(self: *const @This(), allocator: Allocator) void {
            self.value.deinit(allocator);
            allocator.destroy(self.value);
        }
    };

    pub fn init(allocator: Allocator, fields: []StructField) anyerror!Struct {
        var map = std.StringHashMap(*Value).init(allocator);
        errdefer map.deinit();
        for (fields) |field| {
            try map.put(field.name, field.value);
        }
        return .{
            .fields = map,
        };
    }

    pub fn at(self: *const Struct, field: []const u8) ?*Value {
        return self.fields.get(field);
    }

    pub fn deinit(self: *Struct, allocator: Allocator) void {
        var iter = self.fields.iterator();
        while (iter.next()) |f| {
            f.value_ptr.*.deinit(allocator);
            allocator.destroy(f.value_ptr.*);
        }
        self.fields.deinit();
        // for (self.fields) |*field| {
        //     if (field.value) |field_value| {
        //         field_value.deinit(allocator);
        //         allocator.destroy(field_value);
        //     }
        // }
        // allocator.free(self.fields);
    }
};
