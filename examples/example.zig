const std = @import("std");
const lib = @import("zig_plot_lib");
fn generate_x_power_2(comptime N: usize, x: [*]f64, y: [*]f64) void {
    inline for (0..N) |i| {
        y[i] = @as(f64, x[i] * x[i]);
    }
}

fn linspace(comptime N: usize, array: [*]f64, min: f64, max: f64) void {
    const dx = (max - min) / @as(f64, N - 1);
    inline for (0..N) |i| {
        const val = min + dx * @as(f64, i);
        array[i] = val;
    }
}
fn generate_sine_points(comptime N: usize, x: [*]f64, y: [*]f64) void {
    inline for (0..N) |i| {
        y[i] = std.math.sin(x[i]);
    }
}
fn generate_cos_points(comptime N: usize, x: [*]f64, y: [*]f64) void {
    inline for (0..N) |i| {
        y[i] = std.math.cos(x[i] + (std.math.pi / 2.0));
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const width: i32 = 600;
    const height: i32 = 480;
    const N: usize = 500;
    var x: [N]f64 = undefined;
    var y: [N]f64 = undefined;
    const parabola_min = -3;
    const parabola_max = 3;
    var trig_min: f64 = 5 * -std.math.pi;
    var trig_max: f64 = 5 * std.math.pi;

    linspace(N, &x, parabola_min, parabola_max);
    var start = std.time.milliTimestamp();
    var end = std.time.milliTimestamp();

    // zig fmt: off
    var plot: *lib.Plot = try lib.Plot.init(allocator,
    "example.png",
    .custom,
    width,
    height,
    .Light
    );
    plot.image.customCartesianCoordinate(-20, 20, 10,-10);

    plot.image.drawCircle(0, 0,4, lib.color.getColor(.black));
    // zig fmt: on
    defer plot.deinit();
    linspace(N, &x, trig_min, trig_max);
    generate_sine_points(N, &x, &y);
    try plot.plot(&x, &y, 2, lib.color.getColor(.red));
    trig_min = 5 * -(std.math.pi);
    trig_max = 5 * (std.math.pi);

    linspace(N, &x, trig_min, trig_max);
    generate_cos_points(N, &x, &y);
    try plot.plot(&x, &y, 2, lib.color.getColor(.blue));

    linspace(N, &x, parabola_min, parabola_max);
    generate_x_power_2(
        N,
        &x,
        &y,
    );
    try plot.plot(&x, &y, 2, lib.color.getColor(.blue));

    std.debug.print("Time Took for drawing stuff :{d:.4} ms\n", .{end - start});
    start = std.time.milliTimestamp();
    try plot.save();
    end = std.time.milliTimestamp();
    std.debug.print("Time Took for saving plot :{d:.4} ms\n", .{end - start});
}
