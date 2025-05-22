const std = @import("std");
const stdout = std.io.getStdOut().writer();
const lib = @import("zig_plot_lib");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Create a plot with desired width and height
    var plot: lib.Plot = try .init(allocator, null, 1920, 1080);
    defer plot.deinit();

    const n_points = 1000;
    const x_min: f64 = -20.0;
    const x_max: f64 = 20.0;
    const dx = (x_max - x_min) / @as(f64, @floatFromInt(n_points - 1));

    // Allocate arrays dynamically
    const x_arr = try allocator.alloc(f64, n_points);
    defer allocator.free(x_arr);
    const y_arr = try allocator.alloc(f64, n_points);
    defer allocator.free(y_arr);

    // Fill arrays with a parabolic function: y = x^2
    for (x_arr, 0..) |_, i| {
        const x = x_min + dx * @as(f64, @floatFromInt(i));
        x_arr[i] = x;
        y_arr[i] = x_arr[i] * x_arr[i] + 4 * x_arr[i] + 5;
    }

    var start = std.time.milliTimestamp();
    plot.clearPlot(lib.getColor(.white));
    var end = std.time.milliTimestamp();
    try stdout.print("Time Taken to run clearPlot: {} ms\n", .{end - start});

    // Draw X and Y axes
    plot.drawLine(0, 500, 0, -500, lib.getColor(.black), 2);
    plot.drawLine(500, 0, -500, 0, lib.getColor(.black), 2);
    for (0..n_points - 1) |i| {
        const x0 = x_arr[i];
        const y0 = y_arr[i];
        const x1 = x_arr[i + 1];
        const y1 = y_arr[i + 1];
        plot.drawLine(x0, y0, x1, y1, lib.getColor(.red), 1);
    }

    start = std.time.milliTimestamp();
    try plot.drawPoints(x_arr, y_arr, lib.getColor(.blue));
    end = std.time.milliTimestamp();
    try stdout.print("Time Taken to drawPoints: {} ms\n", .{end - start});

    start = std.time.milliTimestamp();
    try plot.savePlot();
    end = std.time.milliTimestamp();
    try stdout.print("Time Taken to savePlot: {} ms\n", .{end - start});
}
