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
    max_value_size: usize = 4096,

    pub fn serialize(self: Command, db: std.fs.File) !void {
        switch (self.operation) {
            Operation.SET => {
                return std.fmt.format(db.writer(), "{s}|{s}|{s}~", .{ "s", self.key, self.value.? });
            },
            Operation.REMOVE => {
                return std.fmt.format(db.writer(), "{s}|{s}~", .{ "r", self.key });
            },
            else => unreachable,
        }
    }
};

pub const ZVS = struct {
    db: std.fs.File = undefined,
    map: std.StringHashMap([]const u8) = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(self: *ZVS, allocator: std.mem.Allocator, db: []const u8) !void {
        self.allocator = allocator;
        const cwd = std.fs.cwd();
        self.db = try cwd.createFile(db, .{ .truncate = false });
        self.map = std.StringHashMap([]const u8).init(allocator);

        // Read the WAL
        self.consume_wal();
    }

    pub fn consume_wal(self: *ZVS) !void {
        _ = self;
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
        try command.serialize(self.db);
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
        try command.serialize(self.db);
        return true;
    }

    pub fn deinit(self: *ZVS) void {
        self.map.deinit();
        self.db.close();
    }
};

const testing = std.testing;
