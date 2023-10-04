const std = @import("std");
const clap = @import("clap");
const io = std.io;
const debug = std.debug;

const zvs = @import("./zvs.zig");

const usage_text =
    \\Usage: zvs [options] command <key> <value>
    \\
    \\A simple key-value store.
;

const Command = struct {
    operation: zvs.Operation = zvs.Operation.GET,
    key: []const u8,
    value: ?[]const u8 = null,
};

fn parse_command(args: *std.process.ArgIterator) Command {
    // throw away the first argument, which is the program name
    _ = args.next();

    var cmd = Command{ .key = "" };

    // Get the operation
    const operation = args.next();
    if (operation == null) {
        std.log.err("No operation specified", .{});
        std.process.exit(1);
    }
    if (std.mem.eql(u8, operation.?, "set")) {
        cmd.operation = zvs.Operation.SET;
    } else if (std.mem.eql(u8, operation.?, "rm")) {
        cmd.operation = zvs.Operation.REMOVE;
    }

    // Get the key
    const key = args.next();
    if (key == null) {
        std.log.err("No key specified", .{});
        std.process.exit(1);
    }

    cmd.key = key.?;

    // Get the optional value
    const value = args.next();
    cmd.value = value;
    return cmd;
}

pub fn main() !void {
    var arena_main = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_main.deinit();

    const allocator = arena_main.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    const cmd = parse_command(&args);
    _ = cmd;
}
