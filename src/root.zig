// Standard Imports
const std = @import("std");
const stdout = std.io.getStdOut().writer();
const cwd = std.fs.cwd();
// Custom Imports
pub const color = @import("color.zig");
const siw = @cImport({
    @cDefine("STB_IMAGE_WRITE_IMPLEMENTATION", "");
    @cInclude("../deps/stb_image_write.h");
});

// STB_IMAGE_WRITE reqirements
export var stbi_write_png_compression_level: c_int = 8;
export var stbi_write_force_png_filter: c_int = -1;

// Type Def
const comp = 4;
const Pixel = [comp]u8;
const vec2u32 = struct { x: u32, y: u32 };

pub const Plot = struct {
    image: Image,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, plot_name: ?[]const u8, cartesian_origin: CartesianOrigin, width: u32, height: u32) !@This() {
        const p_name = plot_name orelse "plot.png";
        return .{
            .image = try .createImage(allocator, p_name, cartesian_origin, width, height),
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.image.destoryImage();
    }
    pub fn setTheme(self: *@This(), theme: Theme) void {
        switch (theme) {
            .Dark => self.image.clearImage(color.getColor(.black)),
            .Light => self.image.clearImage(color.getColor(.white)),
        }
    }
    pub fn savePlot(self: *@This()) !void {
        //try self.image.saveImageBuffered();
        const result = try self.image.saveImage();
        if (result) {
            try stdout.print("Plot saved as \x1b[31m\x1b[1m {s} \x1b[0m \x1b[0m\n", .{self.image.name});
        } else try stdout.print("Unable to save Plot \x1b[31m\x1b[1m {s} \x1b[0m \x1b[0m\n", .{self.image.name});
    }
};

const Theme = enum {
    Dark,
    Light,
};

const Image = struct {
    width: u32,
    height: u32,
    name: []const u8,
    image_buffer: []Pixel,
    coord: Coordinate,
    allocator: std.mem.Allocator,

    pub fn createImage(allocator: std.mem.Allocator, image_name: []const u8, cartesian_origin: CartesianOrigin, width: u32, height: u32) !@This() {
        const buffer_len = @as(usize, @intCast(width * height));
        // Check if the buffer size is reasonable for stack allocation
        if (buffer_len * @sizeOf([comp]u8) > 100 * 1024 * 1024) {
            return error.BufferTooLargeForStack;
        }
        return .{
            .width = width,
            .height = height,
            .name = image_name,
            .image_buffer = try allocator.alloc(Pixel, buffer_len),
            .coord = try Coordinate.init(width, height, cartesian_origin),
            .allocator = allocator,
        };
    }

    pub fn destoryImage(self: *@This()) void {
        self.allocator.free(self.image_buffer);
    }

    pub fn saveImageBuffered(self: *@This()) !void {
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

    pub fn saveImage(self: *@This()) !bool {
        const stride_in_bytes = self.width * comp;
        var buff: [256]u8 = undefined;
        const null_terminated_name = try std.fmt.bufPrintZ(&buff, "{s}", .{self.name});
        const raw_bytes = @as([*]const u8, @ptrCast(self.image_buffer.ptr))[0 .. self.image_buffer.len * 3];
        const result = siw.stbi_write_png(null_terminated_name, @intCast(self.width), @intCast(self.height), @intCast(comp), raw_bytes.ptr, @intCast(stride_in_bytes));
        if (result != 1) {
            return false;
        } else return true;
    }

    // pub fn saveImage(self: *@This()) !void {
    //     // This is "ppm6" image format
    //
    //     const file = try cwd.createFile(self.name, .{ .truncate = true });
    //     defer file.close();
    //     const writer = file.writer();
    //
    //     // Write File Header
    //     try writer.print("P6\n{} {}\n{}\n", .{ self.width, self.height, 255 });
    //
    //     // write the image
    //     const raw_bytes = @as([*]const u8, @ptrCast(self.image_buffer.ptr))[0 .. self.image_buffer.len * 3];
    //     try writer.writeAll(raw_bytes);
    // }

    pub fn clearImage(self: *@This(), c: color.Color) void {
        for (self.image_buffer) |*pixel| {
            pixel[0] = c.r;
            pixel[1] = c.g;
            pixel[2] = c.b;
            pixel[3] = c.a;
        }
    }

    fn setImagePixel(self: *@This(), x: u32, y: u32, c: color.Color) void {
        const i: usize = x * y;
        self.image_buffer[i][0] = c.r;
        self.image_buffer[i][1] = c.g;
        self.image_buffer[i][2] = c.b;
        self.image_buffer[i][3] = c.a;
    }

    pub fn drawRectange(self: *@This(), center_x: f64, center_y: f64, rect_width: u32, rect_height: u32, c: color.Color) void {
        // zig fmt: off
        const pixel_coord = self.coord.cartesianToPixel(center_x,center_y);
        Draw.Rectangle(
        self.image_buffer,
        pixel_coord.x,
        pixel_coord.y, 
        rect_width,
        rect_height,
        self.width,
        self.height,
        c);
        // zig fmt: on
    }

    pub fn drawCircle(self: *@This(), center_x: f64, center_y: f64, radius: f64, c: color.Color) void {
        const pixel_coord = self.coord.cartesianToPixel(center_x, center_y);
        const rad: u32 = @intFromFloat(radius);
        // zig fmt: off
        Draw.Circle(
        self.image_buffer,
        pixel_coord.x,
        pixel_coord.y,
        rad,
        self.width,
        self.height,
        c
        );
        // zig fmt: off
    }
    pub fn drawLine(self:*@This(),start_x:f64,start_y:f64,end_x:f64,end_y:f64,thickness:?u32,c:color.Color)void{
        const start_pixel_coord = self.coord.cartesianToPixel(start_x, start_y);
        const end_pixel_coord = self.coord.cartesianToPixel(end_x, end_y);
        // zig fmt: off
        Draw.line(self.image_buffer,
        start_pixel_coord.x,
        start_pixel_coord.y ,
        end_pixel_coord.x,
        end_pixel_coord.y ,
        thickness,
        self.width,
        self.height,
        c
        );
        // zig fmt: on
    }
};
const Draw = struct {
    fn setPixel(buf: []Pixel, index: usize, c: color.Color) void {
        buf[index][0] = c.r;
        buf[index][1] = c.g;
        buf[index][2] = c.b;
        buf[index][3] = c.a;
    }

    fn Rectangle(buffer: []Pixel, center_x: u32, center_y: u32, rect_width: u32, rect_height: u32, canvas_width: u32, canvas_height: u32, c: color.Color) void {
        const half_width: i32 = @intCast(rect_width / 2);
        const half_height: i32 = @intCast(rect_height / 2);
        var dy: i32 = -half_height;
        while (dy < half_height) : (dy += 1) {
            var dx: i32 = -half_width;
            while (dx < half_width) : (dx += 1) {
                const px = @as(i32, @intCast(center_x)) + dx;
                const py = @as(i32, @intCast(center_y)) + dy;
                const w: i32 = @intCast(canvas_width);
                const h: i32 = @intCast(canvas_height);
                if (px >= 0 and py > 0 and px < w and py < h) {
                    const index: usize = @as(usize, @intCast(py * w + px));
                    setPixel(buffer, index, c);
                }
            }
        }
    }
    fn Circle(buffer: []Pixel, center_x: u32, center_y: u32, radius: u32, canvas_width: u32, canvas_height: u32, c: color.Color) void {
        var dy: i32 = -@as(i32, @intCast(radius));
        while (dy < radius) : (dy += 1) {
            var dx: i32 = -@as(i32, @intCast(radius));
            while (dx < radius) : (dx += 1) {
                if ((dx * dx) + (dy * dy) <= radius * radius) {
                    const px = @as(i32, @intCast(center_x)) + dx;
                    const py = @as(i32, @intCast(center_y)) + dy;
                    const w: i32 = @intCast(canvas_width);
                    const h: i32 = @intCast(canvas_height);
                    if (px >= 0 and py > 0 and px < w and py < h) {
                        const index: usize = @as(usize, @intCast(py * w + px));
                        setPixel(buffer, index, c);
                    }
                }
            }
        }
    }
    fn line(buffer: []Pixel, start_x: u32, start_y: u32, end_x: u32, end_y: u32, thickness: ?u32, width: u32, heigth: u32, c: color.Color) void {
        const thick: u32 = thickness orelse 2;
        var x0: i32 = @intCast(start_x);
        var y0: i32 = @intCast(start_y);
        const x1: i32 = @intCast(end_x);
        const y1: i32 = @intCast(end_y);

        const dx: i32 = @intCast(@abs(x1 - x0));
        const sx: i32 = if (x0 < x1) 1 else -1;
        const dy: i32 = -@as(i32, @intCast(@abs(y1 - y0)));
        const sy: i32 = if (y0 < y1) 1 else -1;

        var err_val: i32 = dx + dy;
        var e2: i32 = 0;
        while (true) {
            const px: u32 = @intCast(x0);
            const py: u32 = @intCast(y0);
            Draw.Rectangle(buffer, px, py, thick, thick, width, heigth, c);
            e2 = 2 * err_val;
            if (e2 >= dy) {
                if (x0 == x1) break;
                err_val += dy;
                x0 += sx;
            }
            if (e2 <= dx) {
                if (y0 == y1) break;
                err_val += dx;
                y0 += sy;
            }
        }
    }
};
const Coordinate = struct {
    cart_coord: CartesianCoord,
    pixel_coord: PixelCoord,

    pub fn init(width: u32, height: u32, cartesian_origin: CartesianOrigin) !@This() {
        return .{
            .cart_coord = try .init(width, height, cartesian_origin),
            .pixel_coord = .init(width, height),
        };
    }

    fn cartesianToPixel(self: *@This(), x: f64, y: f64) vec2u32 {
        const x_range = self.cart_coord.right - self.cart_coord.left;
        const y_range = self.cart_coord.bottom - self.cart_coord.top;

        var norm_x = (x - @as(f64, @floatFromInt(self.cart_coord.left))) / @as(f64, @floatFromInt(x_range));
        var norm_y = (y - @as(f64, @floatFromInt(self.cart_coord.top))) / @as(f64, @floatFromInt(y_range));

        norm_x = std.math.clamp(norm_x, 0.0, 1.0);
        norm_y = std.math.clamp(norm_y, 0.0, 1.0);

        const pixel_x = @min(self.cart_coord.width - 1, @as(usize, @intFromFloat(norm_x * @as(f64, @floatFromInt(self.cart_coord.width)))));
        const pixel_y = @min(self.cart_coord.height - 1, @as(usize, @intFromFloat((1.0 - norm_y) * @as(f64, @floatFromInt(self.cart_coord.height)))));
        return .{ .x = pixel_x, .y = pixel_y };
    }
};

const CoordinateType = enum { Pixel, Cartesian, Polar };

const CartesianOrigin = enum {
    center,
    bottom_left_corner,
    bottom_right_corner,
    top_left_corner,
    top_right_corner,
    custom,
};

const CartesianCoord = struct {
    width: u32,
    height: u32,
    left: i32, // Left side of the image
    right: i32, // Right side of the image
    top: i32, // Top side of the image
    bottom: i32, // Bottom side of the image

    pub fn init(width: u32, height: u32, cartesian_origin: CartesianOrigin) !@This() {
        return switch (cartesian_origin) {
            .center => initCartesianCoordCenter(width, height),
            .custom => try initCartesianCoordDummy(),
            .bottom_left_corner => initCartesianCoordBLC(width, height),
            else => unreachable,
        };
    }
    pub fn initCartesianCoordCenter(width: u32, height: u32) @This() {
        const x_center: i32 = @intCast(@divExact(width, 2));
        const y_center: i32 = @intCast(@divExact(height, 2));
        const left = -x_center;
        const right = x_center;
        const top = -y_center;
        const bottom = y_center;
        return .{
            .width = width,
            .height = height,
            .left = left,
            .right = right,
            .top = top,
            .bottom = bottom,
        };
    }
    fn initCartesianCoordDummy() !@This() {
        try stdout.print("Plot Coordinate is not set, use initCartesianCoordC to set coordinates\n", .{});
        return .{
            .width = undefined,
            .height = undefined,
            .left = undefined,
            .right = undefined,
            .top = undefined,
            .bottom = undefined,
        };
    }
    pub fn initCartesianCoordC(width: u32, height: u32, left: u32, right: u32, top: u32, bottom: u32) @This() {
        return .{
            .width = width,
            .height = height,
            .left = left,
            .right = right,
            .top = top,
            .bottom = bottom,
        };
    }
    fn initCartesianCoordBLC(width: u32, height: u32) @This() {
        return .{
            .width = width,
            .height = height,
            .left = -50,
            .right = @intCast(width),
            .top = -50,
            .bottom = @intCast(height),
        };
    }
};
const PixelCoord = struct {
    width: u32,
    height: u32,
    pub fn init(width: u32, height: u32) @This() {
        return .{ .width = width, .height = height };
    }
};
// const Polar
