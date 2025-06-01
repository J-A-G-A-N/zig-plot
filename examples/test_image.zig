const std = @import("std");
const lib = @import("zig_plot_lib");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const width: i32 = 1920;
    const height: i32 = 1080;

    // zig fmt: off
    var start = std.time.milliTimestamp();
    var plot: *lib.Plot = try lib.Plot.init(
    allocator,
    "test_image.png",
    .custom,
    width,
    height,
    .Dark
    );
    defer plot.deinit();
    plot.image.customCartesianCoordinate(-300, 300, 300, -300);
    plot.drawAxis();
    // zig fmt: on
    plot.image.drawCircle(-100, 50, 50, lib.color.getColor(.red));
    plot.image.drawRectange(150, 100, 200, 100, lib.color.getColor(.green));
    var end = std.time.milliTimestamp();
    std.debug.print("Time Took for drawing stuff :{d:.4} ms\n", .{end - start});
    start = std.time.milliTimestamp();
    try plot.save();
    end = std.time.milliTimestamp();
    std.debug.print("Time Took for saving plot :{d:.4} ms\n", .{end - start});
}
