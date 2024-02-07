= Greetd_IPC
  #link("https://sr.ht/~meow_king/greetd_ipc/")[Project page] \
  #link("https://meow_king.srht.site/meow-docs/greetd-ipc/index.html")[API Documentation]
  
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
    
