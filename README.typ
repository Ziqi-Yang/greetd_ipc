= Greetd_IPC

== Installation
Supported Zig Version: `0.13`.

```bash
zig fetch 'https://codeberg.org/meow_king/greetd_ipc/archive/v0.1.1.tar.gz' --save
```

Then you can add this dependency into `build.zig` file:

```zig
const dep = b.dependency("greetd_ipc", .{ .target = target, .optimize = optimize });
const module = dep.module("greetd_ipc");
exe.root_module.addImport("greetd_ipc", module);
```

For other version of Zig, you can include `greetd-ipc.zig` file into your
source directory. 
  
== Usage

```zig
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
    
== Run Example
Build `fakegreet` from #link("https://git.sr.ht/~kennylevinsen/greetd")[greetd] repo.
    
```bash
zig build -Dexample=examples/demo.zig run-example
fakegreet ./zig-out/bin/demo
```
    
Or you can run the following command if you have #link("https://github.com/casey/just")[just] installed.
    
```bash
    just run
```
    
Note `fakegreet` is a testing tool inside greetd's repo. see #link("https://git.sr.ht/~kennylevinsen/greetd/tree/master/item/fakegreet/src/main.rs")[source].
    
