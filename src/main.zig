const std = @import("std");
const lib = @import("zig_plot");
const tf = @import("test_functions.zig");
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const width = 620;
    const height = 480;
    const plot_name = "plot";

    const N = 100;
    var x: [N]f64 = undefined;
    var y: [N]f64 = undefined;
    const pi: f64 = 180;
    const factor = 0.2;
    const min_range: f64 = -factor * pi;
    const max_range: f64 = factor * pi;

    linspace(N, &x, min_range, max_range);
    try tf.xsin(1, &x, &y);
    var rc = try lib.RasterCanvas.init(allocator, width, height, plot_name);
    defer rc.deinit();
    const bounds = try calculateAxisBounds(&x, &y);
    var cartesian_transform = lib.CartesianTansform.init(
        width,
        height,
        bounds.x_min,
        bounds.y_min,
        bounds.x_max,
        bounds.y_max,
    );
    var plot = lib.Plot.init(allocator, rc.asCanvas(), cartesian_transform.asTransform());
    var line_layer = lib.LineLayer.init(allocator, lib.color.getColor(.green), 2);
    defer line_layer.deinit();

    try line_layer.setData(&x, &y);
    try plot.addLayers(line_layer.asLayer());

    plot.render();
    try rc.save();
}
fn linspace(comptime N: usize, x: [*]f64, min: f64, max: f64) void {
    const dx = (max - min) / @as(f64, N - 1);
    for (0..N) |i| {
        x[i] = min + dx * @as(f64, @floatFromInt(i));
    }
}
fn calculateAxisBounds(x: []f64, y: []f64) !AxisBounds {
    if (x.len != y.len or x.len == 0 or y.len == 0) return error.InvalidBound;
    var x_min = x[0];
    var x_max = x[0];
    var y_min = y[0];
    var y_max = y[0];
    for (x, y) |x_val, y_val| {
        x_min = @min(x_val, x_min);
        x_max = @max(x_val, x_max);
        y_min = @min(y_val, y_min);
        y_max = @max(y_val, y_max);
    }
    std.log.debug("x_min :{}, x_max:{}, y_min:{},y_max:{}\n", .{ x_min, x_max, y_min, y_max });
    y_min = normalize(y_min);
    x_min = @round(x_min);

    const x_range = x_max - x_min;
    const y_range = y_max - y_min;
    const x_padding = x_range * 0.1;
    const y_padding = y_range * 0.1;

    // Handle case where range is zero (constant values)
    const final_x_padding = if (x_range == 0) 1.0 else x_padding;
    const final_y_padding = if (y_range == 0) 1.0 else y_padding;
    return AxisBounds{
        .x_min = x_min - final_x_padding,
        .x_max = x_max + final_x_padding,
        .y_min = y_min - final_y_padding,
        .y_max = y_max + final_y_padding,
    };
}
const AxisBounds = struct {
    x_min: f64,
    x_max: f64,
    y_min: f64,
    y_max: f64,
};
pub fn normalize(x_start: f64) f64 {
    if (x_start == 0.0) return 0.0;

    const is_negative = x_start < 0.0;
    var x = if (is_negative) -x_start else x_start;
    var exponent: i32 = 0;

    while (x < 0.1) : (exponent += 1) {
        x *= 10.0;
    }

    if (is_negative) x = -x;

    std.log.debug("Normalized value: {}, Exponent: -{}\n", .{ x, exponent });
    return x;
}
