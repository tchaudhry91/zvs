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
        const cwd = std.fs.cwd();
        self.db = try cwd.createFile(db, .{ .truncate = false });
        // Add empty JSON array if file is empty
        const stat = try self.db.stat();
        if (stat.size == 0) {
            try self.db.writeAll("[]");
        }
        // Seek to the back of the file before the final "]"
        try self.db.seekFromEnd(1);

        self.map = std.StringHashMap([]const u8).init(allocator);
    }

    pub fn get(self: *ZVS, key: []const u8) ?[]const u8 {
        return self.map.get(key);
    }

    pub fn set(self: *ZVS, key: []const u8, value: []const u8) !void {
        // Write a WAL entry
        const command = Command{
            .operation = Operation.SET,
            .key = key,
            .value = value,
        };
        try std.json.stringify(command, .{ .emit_null_optional_fields = false }, self.db.writer());
    }

    pub fn remove(self: *ZVS, key: []const u8) !bool {
        // Write a WAL entry
        const command = Command{
            .operation = Operation.REMOVE,
            .key = key,
        };
        if (self.map.get(key) == null) {
            return false;
        }
        try std.json.stringify(command, .{}, self.db.writer());
        return true;
    }

    pub fn deinit(self: *ZVS) void {
        self.map.deinit();
        self.db.close();
    }
};

const testing = std.testing;
