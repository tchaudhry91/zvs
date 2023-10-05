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

    pub fn serialize(self: Command, db: std.fs.File) !u64 {
        switch (self.operation) {
            Operation.SET => {
                try std.fmt.format(db.writer(), "{s}|{s}|", .{ "s", self.key });
                const log_ptr = try db.getPos();
                try std.fmt.format(db.writer(), "{s}~", .{self.value.?});
                return log_ptr;
            },
            Operation.REMOVE => {
                try std.fmt.format(db.writer(), "{s}|{s}~", .{ "r", self.key });
                return 0;
            },
            else => unreachable,
        }
    }
};

pub const ZVS = struct {
    db: std.fs.File = undefined,
    map: std.StringHashMap(u64) = undefined,
    allocator: std.mem.Allocator = undefined,

    pub fn init(self: *ZVS, allocator: std.mem.Allocator, db: []const u8) !void {
        self.allocator = allocator;
        const cwd = std.fs.cwd();
        self.db = try cwd.createFile(db, .{ .read = true, .truncate = false });
        self.map = std.StringHashMap(u64).init(allocator);

        // Read the WAL
        try self.consumeWal();

        try self.db.seekFromEnd(0);
    }

    pub fn updateMap(self: *ZVS, wal_entry: *const []u8, wal_pos: u64) !void {
        var split_iter = std.mem.splitScalar(u8, wal_entry.*, '|');
        const op = split_iter.next().?;
        if (std.mem.eql(u8, op, "s")) {
            const key = split_iter.next().?;
            const key_alloc = try std.fmt.allocPrint(self.allocator, "{s}", .{key});
            const value: u64 = wal_pos + op.len + 1 + key.len + 1;
            try self.map.put(key_alloc, value);
        }
        if (std.mem.eql(u8, op, "r")) {
            const key = split_iter.next().?;
            _ = self.map.remove(key);
        }
    }

    pub fn consumeWal(self: *ZVS) !void {
        while (true) {
            var buf: [1024]u8 = [_]u8{0} ** 1024;
            var buf_wrap = std.io.fixedBufferStream(&buf);
            const wal_pos = try self.db.getPos();
            if (self.db.reader().streamUntilDelimiter(buf_wrap.writer(), '~', 1024)) {} else |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            }
            try self.updateMap(&buf[0..buf_wrap.pos], wal_pos);
        }
    }

    pub fn get(self: *ZVS, key: []const u8) !?[]const u8 {
        const wal_ptr = self.map.get(key);
        if (wal_ptr == null) {
            return null;
        }
        var buf = [_]u8{0} ** 1024;
        try self.db.seekTo(wal_ptr.?);
        const val = try self.db.reader().readUntilDelimiterOrEof(&buf, '~');
        try self.db.seekFromEnd(0);
        return val.?;
    }

    pub fn set(self: *ZVS, key: []const u8, value: []const u8) !void {
        // Write a WAL entry
        const command = Command{
            .operation = Operation.SET,
            .key = key,
            .value = value,
        };
        const log_ptr = try command.serialize(self.db);
        try self.map.put(key, log_ptr);
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
        _ = try command.serialize(self.db);
        return self.map.remove(key);
    }

    pub fn deinit(self: *ZVS) void {
        self.map.deinit();
        self.db.close();
    }
};

const testing = std.testing;
