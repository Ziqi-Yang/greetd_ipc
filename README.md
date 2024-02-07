# Greetd_IPC

[Project page](https://sr.ht/~meow_king/greetd_ipc/)\
[API
Documentation](https://meow_king.srht.site/meow-docs/greetd-ipc/index.html)

## Installation

For `zig` master branch, run the following command

``` bash
zig fetch 'https://git.sr.ht/~meow_king/greetd_ipc/archive/v0.1.0.tar.gz' --save
    
```

Then you can add this dependency into `build.zig` file:

``` zig
const dep = b.dependency("greetd_ipc", .{ .target = target, .optimize = optimize });
    const module = dep.module("greetd_ipc");
    exe.root_module.addImport("greetd_ipc", module);
    
```

For other version of Zig, you can include `greetd-ipc.zig` file into
your source directory.

## Usage

``` zig
const std = @import("std");

    pub fn main() !void {
        var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
        defer if (gpa_impl.deinit() == .leak) @panic("MEMORY LEAK");
        const gpa = gpa_impl.allocator();
    
        const gipc: GreetdIPC = try GreetdIPC.new(null, gpa);
        defer gipc.deinit();
        const request: Request = .{ .create_session = .{ .username = "user"}};
        try gipc.sendMsg(request);
        const response = try gipc.readMsg();
        std.debug.print("{s}\n", .{std.json.fmt(response, .{})});
    }
    
```

## Run Example

Build `fakegreet` from [greetd](https://git.sr.ht/~kennylevinsen/greetd)
repo.

``` bash
zig build -Dexample=examples/demo.zig run-example
fakegreet ./zig-out/bin/demo
    
```

Or you can run the following command if you have
[just](https://github.com/casey/just) installed.

``` bash
just run
    
```

Note `fakegreet` is a testing tool inside greetd's repo. see
[source](https://git.sr.ht/~kennylevinsen/greetd/tree/master/item/fakegreet/src/main.rs).
