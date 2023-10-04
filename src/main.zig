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
    _ = allocator;

    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help and exit.
        \\-f, --file <str>      Database file to use.
        \\<str> <str> <str>     Positional arguments.
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

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});

    var db_file: []const u8 = "zvs.db";
    if (res.args.file) |file| {
        db_file = file;
    }

    var cmd_args = [3]?[]const u8{ null, null, null };
    if (res.positionals.len > cmd_args.len) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }
    for (res.positionals, 0..) |arg, i| {
        cmd_args[i] = arg;
    }

    var cmd = try parseArgs(cmd_args);
    std.debug.print("Command: {any}", .{cmd});
}

fn parseArgs(args: [3]?[]const u8) !zvs.Command {
    var cmd = zvs.Command{};

    // Get the operation
    const operation = args[0];
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
    const key = args[1];
    if (key == null) {
        std.log.err("No key specified", .{});
        std.process.exit(1);
    }

    cmd.key = key.?;

    // Get the optional value
    const value = args[2];
    cmd.value = value;
    return cmd;
}
