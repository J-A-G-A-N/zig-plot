const std = @import("std");
const stdout = std.io.getStdOut().writer();
const cwd = std.fs.cwd();
// Custom Imports
pub const color = @import("color.zig");
const siw = @cImport({
    @cDefine("STB_IMAGE_WRITE_IMPLEMENTATION", "");
    @cInclude("../deps/stb_image_write.h");
});

// TODO
//implement catmull-rom spline
// ref :
//   https://www.youtube.com/watch?v=DLsqkWV6Cag
//   https://www.youtube.com/watch?v=9_aJGUTePYo
//   https://en.wikipedia.org/wiki/Centripetal_Catmull%E2%80%93Rom_spline
// STB_IMAGE_WRITE reqirements
export var stbi_write_png_compression_level: c_int = 8;
export var stbi_write_force_png_filter: c_int = -1;

// Type Def
const comp = 4;
const Pixel = [comp]u8;
const vec2u32 = struct { x: u32, y: u32 };
pub const LinePlot = struct {
    image: Image,
    allocator: std.mem.Allocator,
    theme: Theme,

    fn create(allocator: std.mem.Allocator, plot_name: ?[]const u8, width: u32, height: u32) !*@This() {
        const p_name = plot_name orelse "plot.png";
        var p = try allocator.create(@This());
        p.image = try .createImage(allocator, p_name, width, height);
        p.allocator = allocator;
        return p;
    }
    pub fn init(allocator: std.mem.Allocator, plot_name: ?[]const u8, width: u32, height: u32, theme: Theme) !*@This() {
        var p = try @This().create(allocator, plot_name, width, height);
        p.setTheme(theme);
        p.image.drawBoundingBox(theme);
        //p.drawAxis(cartesian_origin, theme);
        return p;
    }
    pub fn plot(self: *@This(), x: []f64, y: []f64, line_thickness: u32, c: color.Color) !void {
        if (x.len != y.len) return error.DataLenghtNotEqual;
        try self.image.autoSetAxisBounds(x, y);
        for (0..x.len - 1) |i| {
            const x0 = x[i];
            const x1 = x[i + 1];
            const y0 = y[i];
            const y1 = y[i + 1];
            self.image.drawLine(x0, y0, x1, y1, line_thickness, c);
        }
    }
    pub fn scatter(self: *@This(), x: []f64, y: []f64, radius: ?f64, c: color.Color) !void {
        if (x.len != y.len) return error.DataLenghtNotEqual;
        try self.image.autoSetAxisBounds(x, y);
        const rad: f64 = radius orelse 2.0;
        for (x, y) |x_val, y_val| {
            self.image.drawCircle(x_val, y_val, rad, c);
        }
    }
    pub fn drawAxis(self: *@This()) void {
        const axis_color = color.getColor(switch (self.theme) {
            .Dark => .white,
            .Light => .black,
        });
        const cart_coord = self.image.coord.cart_coord;

        // Convert to float for margin calculation
        const left = @as(f64, @floatFromInt(cart_coord.left));
        const right = @as(f64, @floatFromInt(cart_coord.right));
        const top = @as(f64, @floatFromInt(cart_coord.top));
        const bottom = @as(f64, @floatFromInt(cart_coord.bottom));

        // X axis: horizontal line with x-range padding
        self.image.drawLine(
            left,
            0,
            right,
            0,
            2,
            axis_color,
        );

        // Y axis: vertical line with y-range padding
        self.image.drawLine(
            0,
            top,
            0,
            bottom,
            2,
            axis_color,
        );
        self.image.drawCircle(0, 0, 4, color.getColor(.black));
    }

    pub fn deinit(self: *@This()) void {
        self.image.destoryImage();
        self.allocator.destroy(self);
    }
    pub fn setTheme(self: *@This(), theme: Theme) void {
        self.theme = theme;
        self.image.clearImage(color.getColor(switch (theme) {
            .Dark => .black,
            .Light => .white,
        }));
    }
    pub fn save(self: *@This()) !void {
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
const BoundingBox = struct {
    width: u32,
    height: u32,
    pad: u32,
    top: u32,
    bottom: u32,
    left: u32,
    right: u32,

    pub fn init(image_width: u32, image_height: u32, padding: u32) BoundingBox {
        const pad = padding;
        const right = image_width - pad;
        const bottom = image_height - pad;
        return .{
            .pad = 50,
            .width = right - pad,
            .height = bottom - pad,
            .left = pad,
            .right = right,
            .top = pad,
            .bottom = bottom,
        };
    }
};
const Image = struct {
    width: u32,
    height: u32,
    name: []const u8,
    image_buffer: []Pixel,
    bbox: BoundingBox,
    coord: Coordinate,
    allocator: std.mem.Allocator,

    pub fn createImage(allocator: std.mem.Allocator, image_name: []const u8, width: u32, height: u32) !@This() {
        const buffer_len = @as(usize, @intCast(width * height));
        // Check if the buffer size is reasonable for stack allocation
        if (buffer_len * @sizeOf([comp]u8) > 100 * 1024 * 1024) {
            return error.BufferTooLargeForStack;
        }
        const bbox = BoundingBox.init(width, height, 50);
        return .{
            .width = width,
            .height = height,
            .name = image_name,
            .image_buffer = try allocator.alloc(Pixel, buffer_len),
            .bbox = bbox,
            .coord = try Coordinate.init(width, height),
            .allocator = allocator,
        };
    }

    pub fn destoryImage(self: *@This()) void {
        self.allocator.free(self.image_buffer);
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

    pub fn clearImage(self: *@This(), c: color.Color) void {
        for (self.image_buffer) |*pixel| {
            pixel[0] = c.r;
            pixel[1] = c.g;
            pixel[2] = c.b;
            pixel[3] = c.a;
        }
    }

    fn setImagePixel(self: *@This(), x: u32, y: u32, c: color.Color) void {
        const index: usize = y * self.width + x;
        self.image_buffer[index][0] = c.r;
        self.image_buffer[index][1] = c.g;
        self.image_buffer[index][2] = c.b;
        self.image_buffer[index][3] = c.a;
    }
    pub fn customCartesianCoordinate(self: *@This(), left: f64, right: f64, top: f64, bottom: f64) void {
        const Left: i32 = @intFromFloat(left);
        const Right: i32 = @intFromFloat(right);
        const Top: i32 = @intFromFloat(top);
        const Bottom: i32 = @intFromFloat(bottom);
        self.coord.cart_coord.initCartesianCoordC(self.width, self.height, Left, Right, Top, Bottom);
    }
    pub fn drawRectange(self: *@This(), center_x: f64, center_y: f64, rect_width: u32, rect_height: u32, c: color.Color) void {
        // zig fmt: off
        const pixel_coord = self.coord.cartesianToPixel(center_x,center_y,self.bbox);
        Draw.rectangle(
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
    pub fn autoSetAxisBounds(self: *@This(), x: []f64, y: []f64) !void {
        const bounds = try self.coord.cart_coord.calculateAxisBounds(x, y);
        self.customCartesianCoordinate(bounds.x_min, bounds.x_max, bounds.y_max, bounds.y_min);
    }

    pub fn drawBoundingBox(self: *@This(), theme: Theme) void {
        const bounding_box_color = color.getColor(switch (theme) {
            .Dark => .white,
            .Light => .black,
        });
        const left = self.bbox.left;
        const right = self.bbox.right;
        const top = self.bbox.top;
        const bottom = self.bbox.bottom;

        // Draw bounding box: top, left, bottom, right
        const draw = Draw.line;
        const buf = self.image_buffer;
        const w = self.width;
        const h = self.height;
        draw(buf, left, top, right, top, 2, w, h, bounding_box_color); // Top
        draw(buf, left, top, left, bottom, 2, w, h, bounding_box_color); // Left
        draw(buf, left, bottom, right, bottom, 2, w, h, bounding_box_color); // Bottom
        draw(buf, right, bottom, right, top, 2, w, h, bounding_box_color); // Right
    }
    pub fn drawCircle(self: *@This(), center_x: f64, center_y: f64, radius: f64, c: color.Color) void {
        const pixel_coord = self.coord.cartesianToPixel(center_x, center_y, self.bbox);
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
        const start_pixel_coord = self.coord.cartesianToPixel(start_x, start_y,self.bbox);
        const end_pixel_coord = self.coord.cartesianToPixel(end_x, end_y,self.bbox);
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
    fn setPixel(buf: []Pixel, index: usize, width: u32, height: u32, c: color.Color) void {
        if (index <= @as(usize, @intCast(width * height))) {
            //buf[index] = @as(*Pixel, @constCast(@ptrCast(&c))).*;
            buf[index][0] = c.r;
            buf[index][1] = c.g;
            buf[index][2] = c.b;
            buf[index][3] = c.a;
        }
    }

    // zig fmt: off
    fn rectangle(
        buff:[]Pixel,
        center_x:u32,
        center_y:u32,
        rect_width:u32,
        rect_height:u32,
        canvas_width:u32,
        canvas_height:u32,
        c:color.Color
    )void
    // zig fmt: on
    {
        const half_rect_width: i32 = @intCast(rect_width / 2);
        const half_rect_height: i32 = @intCast(rect_height / 2);
        const center_x_i32: i32 = @intCast(center_x);
        const center_y_i32: i32 = @intCast(center_y);
        const canvas_width_i32: i32 = @intCast(canvas_width);
        const canvas_height_i32: i32 = @intCast(canvas_height);

        const start_x = @max(0, center_x_i32 - half_rect_width);
        const start_y = @max(0, center_y_i32 - half_rect_height);
        const end_x = @min(canvas_width_i32, center_x_i32 + half_rect_width);
        const end_y = @min(canvas_height_i32, center_y_i32 + half_rect_height);

        if (start_x >= end_x or start_y >= end_y) return;

        var py: i32 = start_y;
        while (py < end_y) : (py += 1) {
            const row_start: usize = @intCast(py * canvas_width_i32);
            var px: i32 = start_x;
            while (px < end_x) : (px += 1) {
                const index: usize = row_start + @as(usize, @intCast(px));
                setPixel(buff, index, canvas_width, canvas_height, c);
            }
        }
    }
    fn Circle(buff: []Pixel, center_x: u32, center_y: u32, radius: u32, canvas_width: u32, canvas_height: u32, c: color.Color) void {
        const radius_i32: i32 = @intCast(radius);
        const center_x_i32: i32 = @intCast(center_x);
        const center_y_i32: i32 = @intCast(center_y);
        const canvas_width_i32: i32 = @intCast(canvas_width);
        const canvas_height_i32: i32 = @intCast(canvas_height);
        const radius_squared: i32 = radius_i32 * radius_i32;

        const start_x = @max(0, center_x_i32 - radius_i32);
        const start_y = @max(0, center_y_i32 - radius_i32);
        const end_x = @min(canvas_width_i32, center_x_i32 + radius_i32 + 1);
        const end_y = @min(canvas_height_i32, center_y_i32 + radius_i32 + 1);

        if (start_x >= end_x or start_y >= end_y) return;

        var py: i32 = start_y;
        while (py < end_y) : (py += 1) {
            const dy = py - center_y_i32;
            const dy_squared = dy * dy;
            const row_start: usize = @intCast(py * canvas_width_i32);
            var px: i32 = start_x;
            while (px < end_x) : (px += 1) {
                const dx = px - center_x_i32;
                const distance_squared = (dx * dx) + dy_squared;
                if (distance_squared <= radius_squared) {
                    const index: usize = row_start + @as(usize, @intCast(px));
                    setPixel(buff, index, canvas_width, canvas_height, c);
                }
            }
        }
    }
    fn line(buffer: []Pixel, start_x: u32, start_y: u32, end_x: u32, end_y: u32, thickness: ?u32, width: u32, height: u32, c: color.Color) void {
        const thick: u32 = thickness orelse 2;
        var x0: i32 = @intCast(start_x);
        var y0: i32 = @intCast(start_y);
        const x1: i32 = @intCast(end_x);
        const y1: i32 = @intCast(end_y);

        const dx: i32 = @intCast(@abs(x1 - x0));
        const sx: i32 = if (x0 < x1) 1 else -1;
        const dy: i32 = -@as(i32, @intCast(@abs(y1 - y0)));
        const sy: i32 = if (y0 < y1) 1 else -1;
        const width_i32: i32 = @intCast(width);
        const height_i32: i32 = @intCast(height);
        var err_val: i32 = dx + dy;
        var e2: i32 = 0;

        while (true) {
            if (x0 >= 0 and y0 >= 0 and x0 <= width_i32 and y0 <= height_i32) {
                const px: u32 = @intCast(x0);
                const py: u32 = @intCast(y0);
                if (thick <= 1) {
                    const index = (py * width) + px;
                    setPixel(buffer, index, width, height, c);
                } else {
                    Draw.rectangle(buffer, px, py, thick, thick, width, height, c);
                }
            }
            if (x0 == x1 and y0 == y1) break;
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

    pub fn init(width: u32, height: u32) !@This() {
        return .{
            .cart_coord = try .init(width, height),
            .pixel_coord = .init(width, height),
        };
    }
    fn cartesianToPixel(self: *@This(), x: f64, y: f64, bbox: BoundingBox) vec2u32 {
        const x_left: f64 = @floatFromInt(self.cart_coord.left);
        const x_right: f64 = @floatFromInt(self.cart_coord.right);
        const x_range = x_right - x_left;
        const y_top: f64 = @floatFromInt(self.cart_coord.top);
        const y_bottom: f64 = @floatFromInt(self.cart_coord.bottom);
        const y_range: f64 = y_bottom - y_top;

        // Normalize coordinates to [0, 1] range
        const norm_x = std.math.clamp((x - x_left) / x_range, 0.0, 1.0);
        const norm_y = std.math.clamp((y - y_top) / y_range, 0.0, 1.0);
        const padding = 10;
        const usable_width = bbox.width - (2 * padding);
        const usable_height = bbox.height - (2 * padding);
        // Map to bounding box coordinates instead of full image
        const pixel_x = bbox.left + padding + @as(u32, @intFromFloat(norm_x * @as(f64, @floatFromInt(usable_width))));
        const pixel_y = bbox.top + padding + @as(u32, @intFromFloat(norm_y * @as(f64, @floatFromInt(usable_height))));

        return .{ .x = pixel_x, .y = pixel_y };
    }
    // fn cartesianToPixel(self: *@This(), x: f64, y: f64) vec2u32 {
    //     const x_left: f64 = @floatFromInt(self.cart_coord.left);
    //     const x_right: f64 = @floatFromInt(self.cart_coord.right);
    //     const x_range = x_right - x_left;
    //
    //     const y_top: f64 = @floatFromInt(self.cart_coord.top);
    //     const y_bottom: f64 = @floatFromInt(self.cart_coord.bottom);
    //     const y_range: f64 = y_bottom - y_top;
    //
    //     const norm_x = std.math.clamp((x - x_left) / x_range, 0.0, 1.0);
    //     const norm_y = std.math.clamp((y - y_top) / y_range, 0.0, 1.0);
    //     const width = self.cart_coord.image_width;
    //     const height = self.cart_coord.image_height;
    //     const w: f64 = @floatFromInt(width);
    //     const h: f64 = @floatFromInt(height);
    //
    //     const pixel_x = @min(width - 1, @as(u32, @intFromFloat(norm_x * w)));
    //     //const pixel_y = @min(self.cart_coord.height - 1, @as(u32, @intFromFloat((1.0 - norm_y) * h)));
    //     const pixel_y = @min(height - 1, @as(u32, @intFromFloat((norm_y) * h)));
    //
    //     return .{ .x = pixel_x, .y = pixel_y };
    // }

    fn pixelToCartesian(self: *@This(), px: u32, py: u32) struct { x: f64, y: f64 } {
        const x_left: f64 = @floatFromInt(self.cart_coord.left);
        const x_right: f64 = @floatFromInt(self.cart_coord.right);
        const x_range = x_right - x_left;

        const y_top: f64 = @floatFromInt(self.cart_coord.top);
        const y_bottom: f64 = @floatFromInt(self.cart_coord.bottom);
        const y_range = y_bottom - y_top;

        const w: f64 = @floatFromInt(self.cart_coord.width);
        const h: f64 = @floatFromInt(self.cart_coord.height);

        const norm_x = @as(f64, @floatFromInt(px)) / w;
        const norm_y = @as(f64, @floatFromInt(py)) / h;

        const x = norm_x * x_range + x_left;
        const y = norm_y * y_range + y_top;

        return .{ .x = x, .y = y };
    }
};

const CoordinateType = enum { Pixel, Cartesian, Polar };

const CartesianCoord = struct {
    image_width: u32,
    image_height: u32,
    canvas_width: u32,
    canvas_height: u32,
    left: i32, // Left side of the image
    right: i32, // Right side of the image
    top: i32, // Top side of the image
    bottom: i32, // Bottom side of the image
    pub fn init(width: u32, height: u32) !@This() {
        return .{
            .image_width = width,
            .image_height = height,
            .canvas_width = undefined,
            .canvas_height = undefined,
            .left = undefined,
            .right = undefined,
            .top = undefined,
            .bottom = undefined,
        };
    }

    pub fn initCartesianCoordC(self: *@This(), width: u32, height: u32, left: i32, right: i32, top: i32, bottom: i32) void {
        self.image_width = width;
        self.image_height = height;
        self.left = left;
        self.right = right;
        self.top = top;
        self.bottom = bottom;
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
    fn calculateAxisBounds(self: *@This(), x: []f64, y: []f64) !AxisBounds {
        _ = self;
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
};
const PixelCoord = struct {
    width: u32,
    height: u32,
    pub fn init(width: u32, height: u32) @This() {
        return .{ .width = width, .height = height };
    }
};
// const Polar
