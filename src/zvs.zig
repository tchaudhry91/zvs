const std = @import("std");

pub const Operation = enum {
    GET,
    SET,
    REMOVE,
};

pub const Command = struct {
    operation: Operation = Operation.GET,
    key: []const u8 = undefined,
    value: ?[]const u8 = null,
};

pub const ZVS = struct {
    db: std.fs.File = undefined,
    map: std.StringHashMap([]const u8) = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(self: *ZVS, allocator: std.mem.Allocator, db: []const u8) !void {
        self.allocator = allocator;
        self.db = try std.fs.Dir.createFile(db, std.fs.File.CreateFlags{
            .truncate = false,
            .read = true,
        });
        self.map = std.StringHashMap([]const u8).init(allocator);
    }

    pub fn get(self: *ZVS, key: []const u8) ?[]const u8 {
        return self.map.get(key);
    }

    pub fn set(self: *ZVS, key: []const u8, value: []const u8) !void {
        try self.map.put(key, value);
    }

    pub fn remove(self: *ZVS, key: []const u8) bool {
        return self.map.remove(key);
    }

    pub fn deinit(self: *ZVS) void {
        self.map.deinit();
    }
};

const testing = std.testing;
test "test map" {
    const allocator = testing.allocator;
    var zvs = ZVS{};
    zvs.init(allocator);
    defer zvs.deinit();

    // Add
    try zvs.set("foo", "bar");
    try zvs.set("baz", "qux");

    // Get
    try testing.expectEqual(zvs.get("foo"), "bar");
    try testing.expectEqual(zvs.get("baz"), "qux");

    // Remove
    try testing.expectEqual(zvs.remove("foo"), true);
    try testing.expectEqual(zvs.remove("foo"), false);

    // Get
    try testing.expectEqual(zvs.get("foo"), null);
    try testing.expectEqual(zvs.get("baz"), "qux");
}
