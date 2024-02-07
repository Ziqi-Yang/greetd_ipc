const greetd_ipc = @import("greetd_ipc");
const GreetdIPC = greetd_ipc.GreetdIPC;
const Request  = greetd_ipc.Request;
const Response = greetd_ipc.Response;

const std = @import("std");
const mem = std.mem;
const os = std.os;

const stdin = std.io.getStdIn().reader();

const INPUT_MAX_CHAR_NUM = 200;
const MAX_FAILURES = 1;

const LoginResult = enum {
    success,
    failure
};

fn prompt_stderr_alloc(allocator: mem.Allocator, prompt: []const u8) !?[]const u8 {
    std.debug.print("{s}", .{prompt});
    if (try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', INPUT_MAX_CHAR_NUM)) | value | {
        return if (value.len != 0) value else {
            allocator.free(value);
            return null;
        };
    }
    return null;
}

fn login(cmd: []const u8, allocator: mem.Allocator) !void {
    _ = cmd;
    std.debug.print("{s}\n", .{"========================="});
    var raw_node = std.os.uname().nodename;
    const node = mem.trimRight(u8, &raw_node, "\x00");
    
    var buf: [200]u8 = undefined;
    var input: ?[]const u8 = undefined;
    const username = while (true) {
        input = try prompt_stderr_alloc(
            allocator,
            try std.fmt.bufPrint(&buf, "{s} login: ", .{node})
        );
        if (input) |i| break i;
    };
    defer allocator.free(input.?);
    std.debug.print("> {s}\n", .{username});

    const gipc: GreetdIPC = try GreetdIPC.new(null, allocator);
    defer gipc.deinit();

    const next_request: Request = .{ .create_session = .{ .username = username}};
    try gipc.sendMsg(next_request);
    const resp = try gipc.readMsg();
    std.debug.print("{s}\n", .{std.json.fmt(resp, .{})});
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
        try login("", gpa);
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
