const std = @import("std");
const lib = @import("zig_plot_lib");
const tf = @import("test_functions.zig");

pub fn main() !void {
    // Set Up allocator
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const allocator = da.allocator();

    const width = 1920;
    const height = 1080;
    const N = 100;
    var x: [N]f64 = undefined;
    var y: [N]f64 = undefined;
    const pi = std.math.pi;
    const min_range = -pi;
    const max_range = pi;

    // Generate Points For plotting
    linspace(N, &x, min_range, max_range);
    try tf.tan(null, &x, &y);
    // Create a Plot Instance
    // null for default plot name
    // origin is custom as we are going to set it
    var plot = try lib.Plot.init(allocator, null, .custom, width, height, .Light);
    defer plot.deinit();

    try plot.image.autoSetAxisBounds(&x, &y);
    plot.drawAxis();

    var time_start = std.time.milliTimestamp();
    try plot.plot(&x, &y, 2, lib.color.getColor(.blue));
    var time_end = std.time.milliTimestamp();
    std.debug.print("Time Took to draw Plot: {d:.4} ms\n", .{time_end - time_start});

    time_start = std.time.milliTimestamp();
    try plot.save();
    time_end = std.time.milliTimestamp();
    std.debug.print("Time Took to save Plot: {d:.4} ms\n", .{time_end - time_start});
}

fn linspace(comptime N: usize, x: [*]f64, min: f64, max: f64) void {
    const dx = (max - min) / @as(f64, N - 1);
    inline for (0..N) |i| {
        x[i] = min + dx * @as(f64, i);
    }
}
