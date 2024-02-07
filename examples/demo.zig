const greetd_ipc = @import("greetd_ipc");
const GreetdIPC = greetd_ipc.GreetdIPC;

const std = @import("std");
const mem = std.mem;
const os = std.os;

const stdin = std.io.getStdIn().reader();

const MAX_FAILURES = 5;

const LoginResult = enum {
    success,
    failure
};

fn prompt_stderr(prompt: []const u8) !?[]const u8 {
    std.debug.print("{s}\n", .{prompt});
    var buf: [200]u8 = undefined;
    if (try stdin.readUntilDelimiterOrEof(&buf, '\n')) | value | {
        return value;
    }
    return null;
}

fn login(cmd: []const u8) !void {
    _ = cmd;
    const node = std.os.uname().nodename;
    var buf: [200]u8 = undefined; // NOTE: why 50 will cause error.NoSpaceLeft
    const username = try prompt_stderr(
        try std.fmt.bufPrint(&buf, "{s} login:", .{node})
    );
    std.debug.print("{any}\n", .{username.?});
}

pub fn main() !void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa_impl.deinit() == .leak) @panic("MEMORY LEAK");
    const gpa = gpa_impl.allocator();
    // var arena_impl = std.heap.ArenaAllocator.init(gpa_impl.allocator());
    // defer arena_impl.deinit();
    // const arena = arena_impl.allocator();

    const gipc = try GreetdIPC.new(null, gpa);
    defer gipc.deinit();

    for (0..MAX_FAILURES) |i| {
        _ = i;
        try login("");
    }
    
    // try gipc.sendMsg();
    // const resp = try gipc.readMsg();
    // switch (resp) {
    //     .auth_message => |r| {
    //         std.debug.print("{s}\n", .{r.auth_message});
    //     },
    //     else => {}
    // }
}
