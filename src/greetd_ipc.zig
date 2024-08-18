//! # greeted-ipc
//! Zig implementation for [greetd](https://sr.ht/~kennylevinsen/greetd/) ipc protocol
//! 
//! Example usage:
//! 
//! ```zig
//! const std = @import("std");
//!
//! pub fn main() !void {
//!     var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
//!     defer if (gpa_impl.deinit() == .leak) @panic("MEMORY LEAK");
//!     const gpa = gpa_impl.allocator();
//!
//!     const gipc: GreetdIPC = try GreetdIPC.new(null, gpa);
//!     defer gipc.deinit();
//!     const request: Request = .{ .create_session = .{ .username = "user"}};
//!     try gipc.sendMsg(request);
//!     const response = try gipc.readMsg();
//!     std.debug.print("{s}\n", .{std.json.fmt(response, .{})});
//! }
//!
//! MIT License
//!
//! Copyright (C) 2024  Meow King
//!
//! Permission is hereby granted, free of charge, to any person obtaining a copy
//! of this software and associated documentation files (the "Software"), to deal
//! in the Software without restriction, including without limitation the rights
//! to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//! copies of the Software, and to permit persons to whom the Software is
//! furnished to do so, subject to the following conditions:
//! The above copyright notice and this permission notice shall be included in
//! all copies or substantial portions of the Software.
//!
//! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//! AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//! LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//! OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//! THE SOFTWARE.

const std = @import("std");
const json = std.json;
const mem = std.mem;
const ArenaAllocator = std.heap.ArenaAllocator;

const GREETD_IPC_SOCKET_PATH_ENV_NAME = "GREETD_SOCK";

/// Please use `type` field's default value
pub const Request = union(enum) {
    create_session: struct {
        /// please use the this field's default value
        type: []const u8 = "create_session",
        username: []const u8
    },

    post_auth_message_response: struct {
        /// please use the this field's default value
        type: []const u8 = "post_auth_message_response",
        response: ?[]const u8
    },

    start_session: struct {
        /// please use the this field's default value
        type: []const u8 = "start_session",
        cmd: []const []const u8,
        env: []const []const u8,
    },
    
    cancel_session: struct {
        /// please use the this field's default value
        type: []const u8 = "cancel_session"
    }
};

pub const Response = union(enum) {
    success: struct {},
    err: struct {
        err_type: ResponseErrorType,
        description: []const u8
    },
    auth_message: struct {
        auth_message_type: AuthenticationMsgType,
        auth_message: []const u8,
    },
};

pub const AuthenticationMsgType = enum {
    visible,
    secret,
    info,
    @"error",

    pub fn from_str(name: []const u8) !AuthenticationMsgType {
        if (mem.eql(u8, name, "visible")) {
            return AuthenticationMsgType.visible;
        } else if (mem.eql(u8, name, "secret")) {
            return AuthenticationMsgType.secret;
        } else if (mem.eql(u8, name, "info")) {
            return AuthenticationMsgType.info;
        } else if (mem.eql(u8, name, "error")) {
            return AuthenticationMsgType.@"error";
        } else {
            return error.AuthenticationMsgType;
        }
    }
};

pub const ResponseErrorType = enum {
    auth_error,
    @"error",

    pub fn from_str(name: []const u8) !ResponseErrorType {
        if (mem.eql(u8, name, "auth_error")) {
            return ResponseErrorType.auth_error;
        } else if (mem.eql(u8, name, "error")) {
            return ResponseErrorType.@"error";
        } else {
            return error.invalidResponseErrorType;
        }
    }
};

/// Communication Channel
pub const GreetdIPC = struct {
    const Self = @This();
    
    conn: std.net.Stream,
    arena_impl: *ArenaAllocator,
    endian: std.builtin.Endian,

    /// Create a new GreetdIPC object  
    /// Set `socket_path` to null to automatically get the socket path from environment
    /// variable `GREETD_SOCK`.
    pub fn new(socket_path: ?[]const u8, allocator: std.mem.Allocator) !Self {
        const spath = if (socket_path) |path| path: {
            break :path path;
        } else path: {
            const path = std.posix.getenv(GREETD_IPC_SOCKET_PATH_ENV_NAME);
            if (path == null) {
                return error.greetd_ipc_socket_path_env_not_found;
            }
            break :path path.?;
        };
        
        const conn = try std.net.connectUnixSocket(spath);

        const new_gipc_obj: Self = .{
            .conn = conn,
            .arena_impl = try allocator.create(ArenaAllocator),
            .endian = @import("builtin").cpu.arch.endian()
        };
        new_gipc_obj.arena_impl.* = ArenaAllocator.init(allocator);
        return new_gipc_obj;
    }

    pub fn deinit(self: Self) void {
        const allocator = self.arena_impl.child_allocator;
        self.arena_impl.deinit();
        allocator.destroy(self.arena_impl);
    }

    pub fn sendMsg(self: *const Self, request: Request) !void {
        errdefer self.arena_impl.deinit();
        const allocator = self.arena_impl.allocator();

        const payload = switch (request) {
            inline else => | raw_payload | blk: {
                break :blk try json.stringifyAlloc(
                    allocator, raw_payload, .{ .whitespace = .minified }
                );
            }
        };

        const payload_len: u32 = @intCast(payload.len);

        const msg_len = 4 + payload_len;
        var msg = try allocator.alloc(u8, msg_len);

        mem.writeInt(u32, msg[0..4], payload_len, self.endian);
        mem.copyForwards(u8, msg[4..], payload);

        _ = try self.conn.writeAll(msg);
    }

    pub fn readMsg(self: *const Self) !Response {
        errdefer self.arena_impl.deinit();
        const allocator = self.arena_impl.allocator();
        
        var header_buf: [4]u8 = undefined;
        _ = try self.conn.readAll(&header_buf);
        const payload_len: u32 = mem.readInt(u32, &header_buf, self.endian);
        const payload: []u8 = try allocator.alloc(u8, payload_len);
        _ = try self.conn.readAll(payload);
        
        const raw_response_parsed = try json.parseFromSlice(json.Value, allocator, payload, .{});
        const raw_response = raw_response_parsed.value;
        
        const response_type: []const u8 = raw_response.object.get("type").?.string;
        if (mem.eql(u8, response_type, "success")) {
            return Response { .success = .{} };
        } else if (mem.eql(u8, response_type, "error")) {
            const error_type = try ResponseErrorType.from_str(
                raw_response.object.get("error_type").?.string
            );
            return Response {
                .err = .{
                    .err_type = error_type,
                    .description = raw_response.object.get("description").?.string
                }
            };
        } else if (mem.eql(u8, response_type, "auth_message")) {
            const auth_message_type = try AuthenticationMsgType.from_str(
                raw_response.object.get("auth_message_type").?.string
            );
            return Response {
                .auth_message = .{
                    .auth_message_type = auth_message_type,
                    .auth_message = raw_response.object.get("auth_message").?.string
                }
            };
        } else {
            return error.invalidResponseType;
        }
    }
};

