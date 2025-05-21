const std = @import("std");
const cwd = std.fs.cwd();
const stdout = std.io.getStdOut().writer();
const Pixel = [3]u8;

pub const Plot = struct {
    image: Image,
    coord: PlotCoordinate,
    var Allocator: std.mem.Allocator = undefined;

    const PlotCoordinate = struct {
        width: usize,
        height: usize,
        x_min: i32,
        x_max: i32,
        y_min: i32,
        y_max: i32,

        pub fn initPlotCoordinate(width: usize, height: usize) PlotCoordinate {
            const x_center: i32 = @as(i32, @intCast(width / 2));
            const y_center: i32 = @as(i32, @intCast(height / 2));
            const x_min = -x_center;
            const x_max = x_center;
            const y_min = -y_center;
            const y_max = y_center;
            return .{
                .width = width,
                .height = height,
                .x_min = x_min,
                .x_max = x_max,
                .y_min = y_min,
                .y_max = y_max,
            };
        }

        fn cartesianToPixel(self: *PlotCoordinate, x: f64, y: f64) struct { x: usize, y: usize } {
            const x_range = self.x_max - self.x_min;
            const y_range = self.y_max - self.y_min;

            const norm_x = (x - @as(f64, @floatFromInt(self.x_min))) / @as(f64, @floatFromInt(x_range));
            const norm_y = (y - @as(f64, @floatFromInt(self.y_min))) / @as(f64, @floatFromInt(y_range));

            const pixel_x = @min(self.width - 1, @as(usize, @intFromFloat(norm_x * @as(f64, @floatFromInt(self.width)))));
            const pixel_y = @min(self.height - 1, @as(usize, @intFromFloat((1.0 - norm_y) * @as(f64, @floatFromInt(self.height)))));
            return .{ .x = pixel_x, .y = pixel_y };
        }
    };

    pub fn init(allocator: std.mem.Allocator, plot_name: ?[]const u8, width: usize, height: usize) !Plot {
        const p_name = plot_name orelse "plot.ppm";

        return .{
            .image = try .createImage(allocator, p_name, width, height),
            .coord = .initPlotCoordinate(width, height),
        };
    }

    pub fn clearPlot(self: *Plot, c: Color) void {
        for (self.image.image_buffer) |*pixel| {
            pixel[0] = c.r;
            pixel[1] = c.g;
            pixel[2] = c.b;
        }
    }

    pub fn deinit(self: *Plot) void {
        self.image.destoryImage();
    }

    pub fn savePlot(self: *Plot) !void {
        try stdout.print("Plot saved as \x1b[31m\x1b[1m {s} \x1b[0m \x1b[0m\n", .{self.image.name});
        try self.image.saveImage();
    }

    pub fn drawPoints(self: *Plot, x: []const f64, y: []const f64, c: Color) !void {
        if (x.len != y.len) {
            return error.InvalidPoints;
        }
        const default_rad: f64 = 2;
        for (x, y) |x_val, y_val| {
            self.drawCircle(x_val, y_val, default_rad, c);
        }
    }
    fn drawRectangle(self: *Plot, x: f64, y: f64, rectangle_width: f64, rectangle_height: f64, color: Color) void {
        const pixel_coord = self.coord.cartesianToPixel(x, y);

        const center_x = @as(isize, @intCast(pixel_coord.x));
        const center_y = @as(isize, @intCast(pixel_coord.y));

        const half_width = @as(isize, @intFromFloat(rectangle_width / 2.0));
        const half_height = @as(isize, @intFromFloat(rectangle_height / 2.0));

        var dy: isize = -half_height;
        while (dy < half_height) : (dy += 1) {
            var dx: isize = -half_width;
            while (dx < half_width) : (dx += 1) {
                const px = center_x + dx;
                const py = center_y + dy;
                if (px >= 0 and py > 0 and @as(usize, @intCast(px)) < self.coord.width and @as(usize, @intCast(py)) < self.coord.height) {
                    const index = @as(usize, @intCast(py)) * self.coord.width + @as(usize, @intCast(px));
                    self.image.image_buffer[index][0] = color.r;
                    self.image.image_buffer[index][1] = color.g;
                    self.image.image_buffer[index][2] = color.b;
                }
            }
        }
    }

    fn drawCircle(self: *Plot, x: f64, y: f64, radius: f64, color: Color) void {
        const pixel_coord = self.coord.cartesianToPixel(x, y);

        const center_x = @as(isize, @intCast(pixel_coord.x));
        const center_y = @as(isize, @intCast(pixel_coord.y));
        const rad = @as(isize, @intFromFloat(radius));

        var dy: isize = -rad;
        while (dy < rad) : (dy += 1) {
            var dx: isize = -rad;
            while (dx < rad) : (dx += 1) {
                if ((dx * dx) + (dy * dy) <= rad * rad) {
                    const px = center_x + dx;
                    const py = center_y + dy;
                    if (px >= 0 and px < self.coord.width and py >= 0 and py < self.coord.height) {
                        const index = @as(usize, @intCast(py)) * self.coord.width + @as(usize, @intCast(px));
                        self.image.image_buffer[index][0] = color.r;
                        self.image.image_buffer[index][1] = color.g;
                        self.image.image_buffer[index][2] = color.b;
                    }
                }
            }
        }
    }
};

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};
pub const Colors = enum {
    black,
    white,
    red,
    green,
    blue,
    yellow,
};
pub fn getColor(c: Colors) Color {
    return switch (c) {
        .black => Color{ .r = 0, .g = 0, .b = 0 },
        .white => Color{ .r = 255, .g = 255, .b = 255 },
        .red => Color{ .r = 255, .g = 0, .b = 0 },
        .green => Color{ .r = 0, .g = 255, .b = 0 },
        .blue => Color{ .r = 0, .g = 0, .b = 255 },
        .yellow => Color{ .r = 255, .g = 255, .b = 0 },
    };
}
const Image = struct {
    width: usize,
    height: usize,
    name: []const u8,
    image_buffer: []Pixel,
    var Allocator: std.mem.Allocator = undefined;
    pub fn createImage(allocator: std.mem.Allocator, image_name: []const u8, width: usize, height: usize) !Image {
        const buffer_len = width * height;
        // Check if the buffer size is reasonable for stack allocation
        if (buffer_len * @sizeOf([3]u8) > 100 * 1024 * 1024) {
            return error.BufferTooLargeForStack;
        }
        Allocator = allocator;
        return .{
            .width = width,
            .height = height,
            .name = image_name,
            .image_buffer = try allocator.alloc(Pixel, buffer_len),
        };
    }

    pub fn destoryImage(self: *Image) void {
        Allocator.free(self.image_buffer);
    }

    pub fn saveImage(self: *Image) !void {
        // This is "ppm6" image format

        const file = try cwd.createFile(self.name, .{ .truncate = true });
        defer file.close();
        const writer = file.writer();

        // Write File Header
        try writer.print("P6\n{} {}\n{}\n", .{ self.width, self.height, 255 });

        // write the image
        const raw_bytes = @as([*]const u8, @ptrCast(self.image_buffer.ptr))[0 .. self.image_buffer.len * 3];
        try writer.writeAll(raw_bytes);
    }
};
