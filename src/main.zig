const std = @import("std");
const clap = @import("clap");
const io = std.io;
const debug = std.debug;

const zvs = @import("./zvs.zig");

const Opts = enum {
    HELP,
    DATABASE,
};

pub fn main() !void {
    var arena_main = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_main.deinit();
    const allocator = arena_main.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help and exit.
        \\-f, --file <str>      Database file to use.
        \\<str>                 Operation
        \\<str>                 Key
        \\<str>                 Value
    );
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
    }) catch |err| {
        // Report useful error and exit
        diag.report(io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try printUsage();
        return;
    }

    var db_file: []const u8 = "zvs.db";
    if (res.args.file) |file| {
        db_file = file;
    }

    var cmd_args = [3]?[]const u8{ null, null, null };
    if (res.positionals.len > cmd_args.len) {
        try printUsage();
        return error.@"Too many arguments";
    }
    for (res.positionals, 0..) |arg, i| {
        cmd_args[i] = arg;
    }

    var cmd = parseArgs(cmd_args) catch {
        try printUsage();
        return error.@"Invalid arguments";
    };

    // Build the KV Store
    var db = zvs.ZVS{};
    try db.init(allocator, db_file);
    defer db.deinit();

    // Dispatch the command
    switch (cmd.operation) {
        zvs.Operation.GET => {
            const val = try db.get(cmd.key);
            if (val == null) {
                return error.@"Key not found";
            }
            try io.getStdOut().writeAll(val.?);
        },
        zvs.Operation.SET => {
            try db.set(cmd.key, cmd.value.?);
            return;
        },
        zvs.Operation.REMOVE => {
            if (try db.remove(cmd.key)) {
                return;
            } else {
                return error.@"Key not found";
            }
        },
    }
}

fn printUsage() !void {
    try std.io.getStdErr().writeAll("ZVS. A simple key-value store.\nUsage: zvs [-f <file>] <operation> <key> [<value>]\n");
}

fn parseArgs(args: [3]?[]const u8) !zvs.Command {
    var cmd = zvs.Command{};

    // Get the operation
    const operation = args[0];
    if (operation == null) {
        return error.@"Operation is required";
    }
    if (std.mem.eql(u8, operation.?, "set")) {
        cmd.operation = zvs.Operation.SET;
    } else if (std.mem.eql(u8, operation.?, "rm")) {
        cmd.operation = zvs.Operation.REMOVE;
    }

    // Get the key
    const key = args[1];
    if (key == null) {
        return error.@"Key is required";
    }

    cmd.key = key.?;

    // Get the optional value
    const value = args[2];
    cmd.value = value;
    return cmd;
}
