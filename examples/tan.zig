const std = @import("std");
const lib = @import("zig_plot_lib");
pub fn main() !void {
    const width = 800;
    const height = 600;

    const N: usize = 100;
    var x: [N]f64 = undefined;
    var y: [N]f64 = undefined;
    const pi = std.math.pi;
    const min = -pi;
    const max = pi;
    linspace(N, &x, min, max);

    tan(&x, &y);
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const allocator = da.allocator();

    var plot = try lib.LinePlot.init(allocator, "tan.png", width, height, .Dark);
    defer plot.deinit();

    plot.image.customCartesianCoordinate(-10, 10, 100, -100);
    try plot.plot(&x, &y, 2, lib.color.getColor(.red));
    try plot.save();
}

fn linspace(N: usize, array: [*]f64, min: f64, max: f64) void {
    var i: usize = 0;
    const delta = (max - min) / @as(f64, @floatFromInt(N - 1));
    while (i < N) : (i += 1) {
        array[i] = min + delta * @as(f64, @floatFromInt(i));
    }
}
fn tan(x: []f64, y: []f64) void {
    for (x, y) |*x_val, *y_val| {
        y_val.* = std.math.tan(x_val.*);
    }
}
