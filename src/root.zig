const std = @import("std");

pub fn ReplContext(comptime StateType: type) type {
    return struct {
        state: StateType,
        processFn: *const fn (state: *StateType, line: []const u8) anyerror!?[]u8,

        pub fn process(self: *@This(), line: []const u8) !?[]u8 {
            return self.processFn(&self.state, line);
        }
    };
}
pub fn repl(ctx: anytype, allocator: std.mem.Allocator) !void {
    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    const stdin = &stdin_reader.interface;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    while (true) {
        // Show prompt
        try stdout.writeAll("> ");
        try stdout.flush();

        // Read line
        const bare_line = (stdin.takeDelimiter('\n') catch |e| return e) orelse "";
        const line = std.mem.trim(u8, bare_line, "\r\n \t");

        // Process line
        const output = try ctx.process(line) orelse return; // null means exit
        defer allocator.free(output);

        // Write output
        try stdout.print("{s}\n", .{output});
        try stdout.flush();
    }
}
