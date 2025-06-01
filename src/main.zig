const std = @import("std");
const lib = @import("zig_plot_lib");
fn generate_x_power_2(comptime N: usize, x: [*]f64, y: [*]f64) void {
    inline for (0..N) |i| {
        y[i] = @as(f64, x[i] * x[i]);
    }
}

fn linspace(comptime N: usize, array: [*]f64, min: f64, max: f64) void {
    const dx = (max - min) / @as(f64, N - 1);
    //dx *= 2.8;
    inline for (0..N) |i| {
        const val = min + dx * @as(f64, i);
        array[i] = val;
    }
}
fn generate_sine_points(comptime N: usize, x: [*]f64, y: [*]f64) void {
    inline for (0..N) |i| {
        y[i] = std.math.cos(x[i]);
    }
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const width: i32 = 1920;
    const height: i32 = 1080;
    const N: usize = 50;
    var x: [N]f64 = undefined;
    var y: [N]f64 = undefined;
    const parabola_min = -2;
    const parabola_max = 2;
    const trig_min = -5;
    const trig_max = 5;

    linspace(N, &x, parabola_min, parabola_max);
    var start = std.time.milliTimestamp();
    var end = std.time.milliTimestamp();

    // zig fmt: off
    var plot: *lib.Plot = try lib.Plot.init(allocator,
    null,
    .custom,
    width,
    height,
    .Light
    );
    plot.image.customCartesianCoordinate(-20, 20, -5,5);
    plot.drawAxis(.custom, .Light);
    plot.image.drawCircle(0, 0,4, lib.color.getColor(.black));
    // zig fmt: on
    defer plot.deinit();
    linspace(N, &x, trig_min, trig_max);
    generate_sine_points(N, &x, &y);
    plotpoints(plot, N, &x, &y, lib.color.getColor(.red));
    // try plot.image.drawPoints(&x, &y, null, lib.color.getColor(.blue));
    linspace(N, &x, parabola_min, parabola_max);
    generate_x_power_2(
        N,
        &x,
        &y,
    );
    // //try plot.image.drawPoints(&x, &y, null, lib.color.getColor(.red));
    plotpoints(plot, N, &x, &y, lib.color.getColor(.blue));

    std.debug.print("Time Took for drawing stuff :{d:.4} ms\n", .{end - start});
    start = std.time.milliTimestamp();
    try plot.save();
    end = std.time.milliTimestamp();
    std.debug.print("Time Took for saving plot :{d:.4} ms\n", .{end - start});
}
fn plotpoints(p: *lib.Plot, comptime N: usize, x: [*]f64, y: [*]f64, c: lib.color.Color) void {
    for (0..N - 1) |i| {
        const x0 = x[i];
        const x1 = x[i + 1];
        const y0 = y[i];
        const y1 = y[i + 1];
        p.image.drawLine(x0, y0, x1, y1, null, c);
    }
}

// chatgpt
// fn autoSetCartesianCoordinate(plot: *lib.Plot, x: []const f64, y: []const f64) void {
//     if (x.len == 0 or y.len == 0) return;
//
//     var x_min = x[0];
//     var x_max = x[0];
//     var y_min = y[0];
//     var y_max = y[0];
//
//     for (x) |val| {
//         if (val < x_min) x_min = val;
//         if (val > x_max) x_max = val;
//     }
//     for (y) |val| {
//         if (val < y_min) y_min = val;
//         if (val > y_max) y_max = val;
//     }
//
//     // Add a margin (5-10% of range)
//     const x_margin = 0.05 * (x_max - x_min);
//     const y_margin = 0.05 * (y_max - y_min);
//
//     const x0 = x_min - x_margin;
//     const x1 = x_max + x_margin;
//     const y0 = y_min - y_margin;
//     const y1 = y_max + y_margin;
//
//     plot.image.customCartesianCoordinate(x0, x1, y0, y1);
// }
