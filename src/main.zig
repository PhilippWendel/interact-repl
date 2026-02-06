const std = @import("std");
const interact_repl = @import("interact_repl");

const Command = enum {
    // zig fmt: off
    empty, unknown, // This needs to be first because of comptime function fromString
    exit, quit,
    help, usage,
    result, add,
    // zig fmt: on

    pub fn fromString(str: []const u8) Command {
        if (str.len == 0) return .empty;
        // Starts at index 2
        inline for (@typeInfo(Command).@"enum".fields[2..]) |field| {
            if (std.mem.eql(u8, str, field.name)) {
                return @enumFromInt(field.value);
            }
        }
        return .unknown;
    }
};

const CalcState = struct {
    allocator: std.mem.Allocator,
    last_result: i64 = 0,
};

fn calculate(state: *CalcState, line: []const u8) !?[]u8 {
    var tokens = std.mem.tokenizeAny(u8, line, " \t"); // Tokenize on whitespace
    const cmd_str = tokens.next() orelse "";
    const cmd = Command.fromString(cmd_str);

    return blk: switch (cmd) {
        .exit, .quit => break :blk null,
        .empty => break :blk try std.fmt.allocPrint(state.allocator, "Empty command", .{}),
        .unknown => try std.fmt.allocPrint(state.allocator, "Unknown command: {s}", .{cmd_str}),
        .help, .usage => break :blk try std.fmt.allocPrint(state.allocator,
            \\ Usage
            \\  Current result: {d}
            \\  Commands
            \\    help, usage - Prints this message
            \\    quit, exit - Duh
            \\    add n - Adds a number to the last result
            \\    result - Prints the last result
        , .{state.last_result}),
        .add => {
            const num_str = tokens.next() orelse break :blk try std.fmt.allocPrint(state.allocator, "add requires a number argument", .{});
            const num = try std.fmt.parseInt(i64, num_str, 10);
            state.last_result += num;
            continue :blk .result;
        },
        .result => break :blk try std.fmt.allocPrint(state.allocator, "Result: {d}", .{state.last_result}),
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout: *std.io.Writer = &stdout_writer.interface;

    try stdout.writeAll("Calculator REPL (type 'help' for info)\n");
    try stdout.flush();

    var ctx = interact_repl.ReplContext(CalcState){
        .state = .{ .allocator = allocator },
        .processFn = calculate,
    };

    try interact_repl.repl(&ctx, allocator);
}

inline fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
