const std = @import("std");
const lib = @import("zig_plot_lib");

pub fn main() !void {

    // Set Up allocator
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const allocator = da.allocator();

    const width = 620;
    const height = 480;
    const N = 400;
    var x: [N]f64 = undefined;
    var y: [N]f64 = undefined;
    const pi = 180;
    const min_range = -pi / 6.0;
    const max_range = pi / 6.0;

    // Generate Points For plotting
    linspace(N, &x, min_range, max_range);
    try sin(&x, &y);

    // Create a Plot Instance
    // null for default plot name
    // origin is custom as we are going to set it
    var plot = try lib.LinePlot.init(allocator, "sine.png", width, height, .Light);
    defer plot.deinit();

    plot.image.customCartesianCoordinate(-40, 40, 5, -5);
    plot.image.drawCircle(0, 0, 4, lib.color.getColor(.black));

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
const MathError = error{
    MismatchedLengths,
};
fn sin(x: []f64, y: []f64) !void {
    if (x.len != y.len) return MathError.MismatchedLengths;
    for (0..x.len) |i| {
        y[i] = std.math.sin(x[i]);
    }
}
