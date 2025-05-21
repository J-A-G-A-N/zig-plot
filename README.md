# zig-plot-lib

A simple plotting library in Zig that renders 2D plots and saves them as `.ppm` (P6) image files.

This library allows you to:
- Draw points on a Cartesian coordinate system.
- Save the plotted image in raw binary PPM format.
- Time execution of drawing and saving steps.

---

## 🚀 Getting Started

### 📦 Build

Make sure you have [Zig](https://ziglang.org/download/) installed.
version : 0.14.0

```sh
zig build run
feh plot.ppm
```


### Example program
```zig
const std = @import("std");
const stdout = std.io.getStdOut().writer();
const lib = @import("zig_plot_lib");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var plot: lib.Plot = try .init(allocator, null, 1920, 1080);
    defer plot.deinit();
    plot.clearPlot(lib.getColor(lib.Colors.white));
    var x_arr: [20]f64 = undefined;
    var y_arr: [20]f64 = undefined;
    for (0..x_arr.len) |i| {
        x_arr[i] = (@floatFromInt(i * 10));
        y_arr[i] = 100 * @sin(x_arr[i]);
    }
    var start = std.time.milliTimestamp();
    try plot.drawPoints(&x_arr, &y_arr, lib.getColor(lib.Colors.black));
    var end = std.time.milliTimestamp();
    try stdout.print("Time Taken to run drawPoints:{} ms\n", .{end - start});
    start = std.time.milliTimestamp();
    try plot.savePlot();
    end = std.time.milliTimestamp();
    try stdout.print("Time Taken to run savePlot:{} ms\n", .{end - start});
}

```
