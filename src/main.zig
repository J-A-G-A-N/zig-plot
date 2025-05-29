const std = @import("std");
const lib = @import("zig_plot_lib");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const width: i32 = 1920;
    const height: i32 = 1080;

    var plot: lib.Plot = try lib.Plot.init(allocator, null, .center, width, height);
    defer plot.deinit();

    plot.setTheme(.Light);

    plot.image.drawLine(0, -300, 0, 300, 2, lib.color.getColor(.black));
    plot.image.drawLine(-300, 0, 300, 0, 2, lib.color.getColor(.black));
    const start = std.time.milliTimestamp();
    try plot.savePlot();
    const end = std.time.milliTimestamp();
    std.debug.print("Time Took for saving plot :{d:.4} ms\n", .{end - start});
}
