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

            var norm_x = (x - @as(f64, @floatFromInt(self.x_min))) / @as(f64, @floatFromInt(x_range));
            var norm_y = (y - @as(f64, @floatFromInt(self.y_min))) / @as(f64, @floatFromInt(y_range));

            norm_x = std.math.clamp(norm_x, 0.0, 1.0);
            norm_y = std.math.clamp(norm_y, 0.0, 1.0);

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
        //try self.image.saveImageBuffered();
        try self.image.saveImage();
    }

    pub fn drawPoints(self: *Plot, x: []const f64, y: []const f64, c: Color) !void {
        if (x.len != y.len) {
            return error.InvalidPoints;
        }
        const default_rad: f64 = 3;
        for (x, y) |x_val, y_val| {
            self.drawCircle(x_val, y_val, default_rad, c);
        }
    }

    pub fn drawRectangle(self: *Plot, x: f64, y: f64, rectangle_width: f64, rectangle_height: f64, color: Color) void {
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
                    self.image.setPixel(index, color);
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
                        self.image.setPixel(index, color);
                    }
                }
            }
        }
    }
    pub fn drawLine(self: *Plot, x0: f64, y0: f64, x1: f64, y1: f64, color: Color, thickness: usize) void {
        const p0 = self.coord.cartesianToPixel(x0, y0);
        const p1 = self.coord.cartesianToPixel(x1, y1);

        const x0f = @as(f64, @floatFromInt(p0.x));
        const y0f = @as(f64, @floatFromInt(p0.y));
        const x1f = @as(f64, @floatFromInt(p1.x));
        const y1f = @as(f64, @floatFromInt(p1.y));

        const dx = x1f - x0f;
        const dy = y1f - y0f;
        const steps = @max(@abs(dx), @abs(dy));

        if (steps == 0) return; // Prevent div by zero

        const x_inc = dx / steps;
        const y_inc = dy / steps;

        var xf = x0f;
        var yf = y0f;

        const half_thick = @as(i64, @intCast(thickness / 2));

        var i: usize = 0;
        while (i <= @as(usize, @intFromFloat(steps))) : (i += 1) {
            const xi = @as(i64, @intFromFloat(@round(xf)));
            const yi = @as(i64, @intFromFloat(@round(yf)));

            // Draw a square of pixels centered around (xi, yi)
            var dy_off: i64 = -half_thick;
            while (dy_off <= half_thick) : (dy_off += 1) {
                var dx_off: i64 = -half_thick;
                while (dx_off <= half_thick) : (dx_off += 1) {
                    const px = xi + dx_off;
                    const py = yi + dy_off;

                    if (px >= 0 and py >= 0 and px < self.coord.width and py < self.coord.height) {
                        const ux = @as(usize, @intCast(px));
                        const uy = @as(usize, @intCast(py));
                        const index = uy * self.coord.width + ux;
                        self.image.setPixel(index, color);
                    }
                }
            }

            xf += x_inc;
            yf += y_inc;
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
    fn setPixel(self: *Image, index: usize, c: Color) void {
        self.image_buffer[index][0] = c.r;
        self.image_buffer[index][1] = c.g;
        self.image_buffer[index][2] = c.b;
    }

    pub fn saveImageBuffered(self: *Image) !void {
        const file = try cwd.createFile(self.name, .{ .truncate = true });
        defer file.close();

        var buffered_writer = std.io.bufferedWriter(file.writer());
        const writer = buffered_writer.writer();

        // Write header
        try writer.print("P6\n{} {}\n{}\n", .{ self.width, self.height, 255 });

        // Write image data
        const raw_bytes = @as([*]const u8, @ptrCast(self.image_buffer.ptr))[0 .. self.image_buffer.len * 3];
        try writer.writeAll(raw_bytes);

        try buffered_writer.flush();
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
