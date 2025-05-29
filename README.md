# zig-plot-lib

A simple plotting library in Zig that renders 2D plots and saves them as `.ppm` (P6) image files.
This library is underdevelopment.
This library currently allows you to:
- Draw points on a Cartesian coordinate system.
- Save the plotted image in raw binary PPM format.
- Time execution of drawing and saving steps.

---

## 🚀 Getting Started

### 📦 Build

Make sure you have [Zig](https://ziglang.org/download/) installed.
version : 0.14.0

```sh
zig build run --release=fast
# To view
feh plot.png
```


### Example program
```zig
const std = @import("std");
const lib = @import("zig_plot_lib");
fn generate_x_power_2(comptime N: usize, x: [*]f64, y: [*]f64) void {
    inline for (0..N) |i| {
        x[i] = @as(f64, @floatFromInt(2 * i));
        y[i] = @as(f64, x[i] * x[i]);
    }
}

fn generate_sine_points(comptime N: usize, x: [*]f64, y: [*]f64, x_min: f64, x_max: f64) void {
    var dx = (x_max - x_min) / @as(f64, N - 1);
    dx *= 2.8;
    inline for (0..N) |i| {
        const x_val = x_min + dx * @as(f64, i);
        x[i] = x_val;
        y[i] = -20.0 * std.math.sin(x_val);
    }
}
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const width: i32 = 1920;
    const height: i32 = 1080;
    const N: usize = 10;
    var x: [N]f64 = undefined;
    var y: [N]f64 = undefined;

    var plot: *lib.Plot = try lib.Plot.init(allocator, null, .center, width, height, .Light);
    defer plot.deinit();

    generate_x_power_2(N, &x, &y);
    try plot.image.drawPoints(&x, &y, null, lib.color.getColor(.red));
    generate_sine_points(N, &x, &y, 0, 100);
    try plot.image.drawPoints(&x, &y, null, lib.color.getColor(.blue));
    const start = std.time.milliTimestamp();
    try plot.savePlot();
    const end = std.time.milliTimestamp();
    std.debug.print("Time Took for saving plot :{d:.4} ms\n", .{end - start});
}
```
Output Plot:

![Resultant Plot][https://github.com/J-A-G-A-N/zig-plot/blob/17f88fea489431826e5c20a3fa77fbc3fb83b6bc/plot.png]

