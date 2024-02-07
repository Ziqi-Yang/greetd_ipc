const greetd_ipc = @import("greetd_ipc");
const GreetdIPC = greetd_ipc.GreetdIPC;
const Request  = greetd_ipc.Request;
const Response = greetd_ipc.Response;

const std = @import("std");
const mem = std.mem;
const os = std.os;

const stdin = std.io.getStdIn().reader();
const stderr = std.io.getStdOut().writer();

const INPUT_MAX_CHAR_NUM = 200;
const MAX_FAILURES = 5;

const LoginResult = enum {
    success,
    failure
};

fn prompt_stderr_alloc(allocator: mem.Allocator, prompt: []const u8) !?[]const u8 {
    try stderr.print("{s}", .{prompt});
    if (try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', INPUT_MAX_CHAR_NUM)) | value | {
        return if (value.len != 0) value else {
            allocator.free(value);
            return null;
        };
    }
    return null;
}

// note: in fakegreet, CMD won't be executed
fn login(cmd: []const u8, allocator: mem.Allocator) !LoginResult {
    try stderr.print("{s}\n", .{"=========== Login ==========="});
    var raw_node = std.os.uname().nodename;
    const node = mem.trimRight(u8, &raw_node, "\x00");
    
    var buf: [200]u8 = undefined;
    var input: ?[]const u8 = undefined;
    const username = while (true) {
        input = try prompt_stderr_alloc(
            allocator,
            try std.fmt.bufPrint(&buf, "{s} login:", .{node})
        );
        if (input) |i| break i;
    };
    defer allocator.free(input.?);

    const gipc: GreetdIPC = try GreetdIPC.new(null, allocator);
    defer gipc.deinit();

    var res: LoginResult = LoginResult.success;
    var starting: bool = false;
    var next_request: Request = .{ .create_session = .{ .username = username}};
    while (true) {
        try gipc.sendMsg(next_request);
        switch (next_request) {
            .post_auth_message_response => |resp| {
                if (resp.response) |response| {
                    allocator.free(response);
                }
            },
            else => {}
        }

        switch (try gipc.readMsg()) {
            .success => {
                switch (res) {
                    .success => {
                        if (starting) {
                            return res;
                        } else {
                            starting = true;
                            next_request = .{ .start_session = .{
                                .cmd = &.{ cmd },
                                .env = &.{}
                            }};
                        }
                    },
                    .failure => {
                        return res;
                    }
                }
            },
            .err => |err| {
                next_request = Request { .cancel_session = .{} };
                switch (err.err_type) {
                    .auth_error => {
                        res = LoginResult.failure;
                    },
                    .@"error" => {
                        try stderr.print("login error: {s}", .{err.description});
                        return error.Error;
                    }
                }
            },
            .auth_message => |auth_msg| {
                const response: ?[]const u8 = switch (auth_msg.auth_message_type) {
                    .visible => try prompt_stderr_alloc(allocator, auth_msg.auth_message),
                    .secret => try prompt_stderr_alloc(allocator, auth_msg.auth_message),
                    .info => blk: {
                        try stderr.print("info: {s}\n", .{auth_msg.auth_message});
                        break :blk null;
                    },
                    .@"error" => blk: {
                        try stderr.print("error: {s}\n", .{auth_msg.auth_message});
                        break :blk null;
                    }
                };
                next_request = .{ .post_auth_message_response = .{ .response = response }};
            }
        }
    }
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

    for (0..MAX_FAILURES) |_| {
        const res = try login("echo 1", gpa);
        switch (res) {
            .success => {
                try stderr.print("[demo] Login success\n", .{});
                break;
            },
            .failure => {
                try stderr.print("Login incorrect\n", .{});
            }
        }
    }
}
