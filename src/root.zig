const std = @import("std");

pub fn HelloWorld() void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("Hello World!\n", .{}) catch |err| switch (err) {
        else => std.debug.print("{any}\n", .{err}),
    };
}
