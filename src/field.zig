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
    array: Array,

    pub fn field(self: *const Value, field_name: []const u8) ?*Value {
        return self.@"struct".at(field_name);
    }

    pub fn at(self: *const Value, index: usize) ?*Value {
        return if (self.array.inners.items.len > index)
            self.array.inners.items[index]
        else
            null;
    }

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

    pub fn arrayValue(a: Array) Value {
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
            .array => |*a| {
                a.deinit(allocator);
            },

            else => {},
        }
    }
};

pub const Array = struct {
    inners: std.ArrayList(*Value),

    pub fn init(items: std.ArrayList(*Value)) Array {
        return .{
            .inners = items,
        };
    }

    pub fn deinit(self: *Array, allocator: Allocator) void {
        for (self.inners.items) |item| {
            item.deinit(allocator);
            allocator.destroy(item);
        }
        self.inners.deinit();
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
        errdefer {
            var iter = map.iterator();
            while (iter.next()) |pair| {
                allocator.free(pair.key_ptr.*);
                pair.value_ptr.*.deinit(allocator);
                allocator.destroy(pair.value_ptr.*);
            }
            map.deinit();
        }
        for (fields) |field| {
            const name = try allocator.dupe(u8, field.name);
            errdefer allocator.free(name);
            try map.put(name, field.value);
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
            allocator.free(f.key_ptr.*);
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
