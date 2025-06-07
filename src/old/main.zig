const std = @import("std");
const lib = @import("zig_plot");
const tf = @import("test_functions.zig");
pub fn main() !void {
    // Set Up allocator
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const allocator = da.allocator();

    const width = 800;
    const height = 600;
    const N = 100;
    var x: [N]f64 = undefined;
    var y: [N]f64 = undefined;
    const pi: f64 = 180;
    const factor = 0.2;
    const min_range: f64 = -factor * pi;
    const max_range: f64 = factor * pi;

    // Generate Points For plotting
    linspace(N, &x, min_range, max_range);

    var plot = try lib.LinePlot.init(allocator, null, width, height, .Dark);
    defer plot.deinit();
    try tf.xsin(1, &x, &y);
    try plot.plot(&x, &y, 1, lib.color.getColor(.green));
    plot.image.bbox.printBoundingBox();
    const bbox = plot.image.bbox.returnBoudingBox();
    const font_height = 20;
    const text: []const u8 = "y = x Sin(x) plot";
    try plot.image.drawText(text, font_height, bbox.center_x, bbox.top - font_height);

    const ps_start = std.time.milliTimestamp();
    try plot.save();
    const ps_end = std.time.milliTimestamp();
    std.debug.print("Time Taken to save plot :{} ms\n", .{ps_end - ps_start});
}

fn linspace(comptime N: usize, x: [*]f64, min: f64, max: f64) void {
    const dx = (max - min) / @as(f64, N - 1);
    for (0..N) |i| {
        x[i] = min + dx * @as(f64, @floatFromInt(i));
    }
}
