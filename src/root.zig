const std = @import("std");
pub const core = @import("core.zig");
pub const color = core.color;
pub const Font = @import("Font.zig").Font;
export var stbi_write_png_compression_level: c_int = 8;
export var stbi_write_force_png_filter: c_int = -1;
pub const RasterCanvas = struct {
    width: u32,
    height: u32,
    pixels: []core.color.Color,
    allocator: std.mem.Allocator,
    name: []const u8,
    font: *Font,

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32, name: []const u8) !@This() {
        const pixel_count = width * height;
        const pixels = try allocator.alloc(core.color.Color, pixel_count);
        return @This(){
            .width = width,
            .height = height,
            .pixels = pixels,
            .name = name,
            .font = try Font.init(allocator, "deps/FiraCodeNerdFont-Regular.ttf"),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.font.deinit();
        self.allocator.free(self.pixels);
    }

    pub fn asCanvas(self: *@This()) core.Canvas {
        return core.Canvas{ .ptr = self, .vtable = &.{
            .drawPixel = drawPixelImpl,
            .drawLine = drawLineImpl,
            .drawRectangle = drawRectImpl,
            .drawCircle = drawCircleImpl,
            .drawText = drawTextImpl,
            .clear = clearImpl,
            .getDimensions = getDimensionsImpl,
        } };
    }
    pub fn setPixelSafe(self: *@This(), x: u32, y: u32, c: core.color.Color) void {
        if (x >= self.width or y >= self.height) return;
        const index = y * self.width + x;
        self.pixels[index] = c;
    }
    pub fn drawThickPoint(self: *@This(), x: u32, y: u32, thickness: u32, c: core.color.Color) void {
        const half_thick = thickness / 2;
        const start_x = if (x >= half_thick) x - half_thick else 0;
        const start_y = if (y >= half_thick) y - half_thick else 0;
        const end_x = @min(x + half_thick, self.width);
        const end_y = @min(y + half_thick, self.height);

        var py = start_y;
        while (py < end_y) : (py += 1) {
            var px = start_x;
            while (px < end_x) : (px += 1) {
                self.setPixelSafe(px, py, c);
            }
        }
    }
    pub fn drawPixelImpl(ptr: *anyopaque, x: u32, y: u32, c: core.color.Color) void {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        self.setPixelSafe(x, y, c);
    }
    pub fn drawTextImpl(ptr: *anyopaque, cx: u32, cy: u32, text: []const u8, text_size: f32, c: color.Color) !void {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        try self.font.drawText(self.pixels, text, text_size, cx, cy, self.width, self.height, c);
    }
    pub fn drawLineImpl(ptr: *anyopaque, x0: u32, y0: u32, x1: u32, y1: u32, thickness: u32, c: core.color.Color) void {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        self.drawLineBresenham(x0, y0, x1, y1, thickness, c);
    }
    fn drawRectImpl(ptr: *anyopaque, cx: u32, cy: u32, width: u32, height: u32, c: core.color.Color) void {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        self.drawRectangle(cx, cy, width, height, c);
    }
    pub fn drawCircleImpl(ptr: *anyopaque, cx: u32, cy: u32, radius: u32, c: core.color.Color) void {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        self.drawCircle(cx, cy, radius, c);
    }
    pub fn clearImpl(ptr: *anyopaque, c: color.Color) void {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        for (0..self.height) |dy| {
            for (0..self.width) |dx| {
                const px: u32 = @intCast(dx);
                const py: u32 = @intCast(dy);
                self.setPixelSafe(px, py, c);
            }
        }
    }
    pub fn getDimensionsImpl(ptr: *anyopaque) core.Dim {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        return .{
            .width = self.width,
            .height = self.height,
        };
    }
    pub fn drawLineBresenham(self: *@This(), x0: u32, y0: u32, x1: u32, y1: u32, thickness: u32, c: core.color.Color) void {
        var x0_i32: i32 = @intCast(x0);
        var y0_i32: i32 = @intCast(y0);
        const x1_i32: i32 = @intCast(x1);
        const y1_i32: i32 = @intCast(y1);

        const dx: i32 = @intCast(@abs(x1_i32 - x0_i32));
        const dy: i32 = @intCast(@abs(y1_i32 - y0_i32));

        const sx: i32 = if (x0_i32 < x1_i32) 1 else -1;
        const sy: i32 = if (y0_i32 < y1_i32) 1 else -1;

        var err = dx - dy;

        while (true) {
            if (thickness <= 1) {
                if (x0_i32 >= 0 and y1_i32 >= 0) {}
                self.setPixelSafe(@intCast(x0_i32), @intCast(y0_i32), c);
            } else {
                self.drawThickPoint(@intCast(x0_i32), @intCast(y0_i32), thickness, c);
            }
            if (x0_i32 == x1_i32 and y0_i32 == y1_i32) break;
            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                x0_i32 += sx;
            }
            if (e2 < dx) {
                err += dx;
                y0_i32 += sy;
            }
        }
    }

    pub fn drawCircle(self: *@This(), cx: u32, cy: u32, radius: u32, c: core.color.Color) void {
        var dx: i32 = 0;
        var dy: i32 = @intCast(radius);
        var D: i32 = 3 - 2 * dy;
        const cx_i32: i32 = @intCast(cx);
        const cy_i32: i32 = @intCast(cy);

        while (dy >= dx) : (dx += 1) {
            self.drawSpan(cx_i32 - dx, cx_i32 + dx, cy_i32 + dy, c);
            self.drawSpan(cx_i32 - dx, cx_i32 + dx, cy_i32 - dy, c);
            self.drawSpan(cx_i32 - dy, cx_i32 + dy, cy_i32 + dx, c);
            self.drawSpan(cx_i32 - dy, cx_i32 + dy, cy_i32 - dx, c);
            if (D > 0) {
                dy -= 1;
                D += 4 * (dx - dy) + 10;
            } else {
                D += 4 * dx + 6;
            }
        }
    }

    fn drawSpan(self: *@This(), x0: i32, x1: i32, y: i32, c: core.color.Color) void {
        if (y < 0 or y >= @as(i32, @intCast(self.height))) return;

        const start_x = @max(0, x0);
        const end_x = @min(x1, @as(i32, @intCast(self.width)) - 1);

        var px = start_x;
        while (px <= end_x) : (px += 1) {
            self.setPixelSafe(@intCast(px), @intCast(y), c);
        }
    }

    fn drawRectangle(self: *@This(), cx: u32, cy: u32, width: u32, height: u32, c: core.color.Color) void {
        const half_w: i32 = @intCast(width / 2);
        const half_h: i32 = @intCast(height / 2);

        const start_x: i32 = @as(i32, @intCast(cx)) - half_w;
        const start_y: i32 = @as(i32, @intCast(cy)) - half_h;
        const end_x: i32 = start_x + @as(i32, @intCast(width));
        const end_y: i32 = start_y + @as(i32, @intCast(height));

        var y: i32 = start_y;
        while (y < end_y) : (y += 1) {
            var x: i32 = start_x;
            while (x < end_x) : (x += 1) {
                self.setPixelSafe(@intCast(x), @intCast(y), c);
            }
        }
    }
    pub fn drawText(self: *@This(), cx: u32, cy: u32, text: []const u8, text_size: f32, c: color.Color) !void {
        try self.font.drawText(self.pixels, text, text_size, cx, cy, self.width, self.height, c);
    }
    pub fn save(self: *@This()) !void {
        const siw = @cImport({
            @cDefine("STB_IMAGE_WRITE_IMPLEMENTATION", "");
            @cInclude("../deps/stb_image_write.h");
        });

        const image_format_ext: []const u8 = "png";
        const byte_buffer: []u8 = @as([*]u8, @ptrCast(self.pixels.ptr))[0 .. self.pixels.len * @sizeOf(core.color.Color)];
        const null_terminated_name = try std.fmt.allocPrintZ(self.allocator, "{s}.{s}", .{ self.name, image_format_ext });
        const result = siw.stbi_write_png(
            null_terminated_name,
            @intCast(self.width),
            @intCast(self.height),
            4,
            byte_buffer.ptr,
            @intCast(self.width * 4),
        );
        if (result != 1) return error.FailedToSaveImage else std.debug.print("Plot saved as \x1b[31m\x1b[1m {s} \x1b[0m \x1b[0m\n", .{self.name});
    }
};

pub const CartesianTansform = struct {
    screen_width: u32,
    screen_height: u32,
    data_min_x: f64,
    data_min_y: f64,
    data_max_x: f64,
    data_max_y: f64,

    pub fn init(width: u32, height: u32, data_min_x: f64, data_min_y: f64, data_max_x: f64, data_max_y: f64) @This() {
        return @This(){
            .screen_width = width,
            .screen_height = height,
            .data_min_x = data_min_x,
            .data_min_y = data_min_y,
            .data_max_x = data_max_x,
            .data_max_y = data_max_y,
        };
    }

    pub fn asTransform(self: *@This()) core.CoordianteTransform {
        return core.CoordianteTransform{
            .ptr = self,
            .vtable = &.{
                .worldToScreen = worldToScreenImpl,
                .screenToWorld = screenToWorldImpl,
                .setBounds = setBoundsImpl,
                .getbounds = getBoundsImpl,
            },
        };
    }

    pub fn worldToScreenImpl(ptr: *anyopaque, world_point: core.Point2D) core.Point2D {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        const x_range = self.data_max_x - self.data_min_x;
        const y_range = self.data_max_y - self.data_min_y;

        const norm_x = std.math.clamp((world_point.x - self.data_min_x) / x_range, 0, 1);
        const norm_y = 1.0 - std.math.clamp((world_point.y - self.data_min_y) / y_range, 0, 1);

        const width_f64: f64 = @floatFromInt(self.screen_width);
        const height_f64: f64 = @floatFromInt(self.screen_height);
        const screen_x: u32 = @intFromFloat(norm_x * width_f64);
        const screen_y: u32 = @intFromFloat(norm_y * height_f64);

        return .{
            .x = @floatFromInt(@min(screen_x, self.screen_width - 1)),
            .y = @floatFromInt(@min(screen_y, self.screen_height - 1)),
        };
    }

    pub fn screenToWorldImpl(ptr: *anyopaque, screen_point: core.Point2D) core.Point2D {
        const self: *@This() = @ptrCast(@alignCast(ptr));

        const x_range = self.data_max_x - self.data_min_x;
        const y_range = self.data_max_y - self.data_min_y;

        const width_f64: f64 = @floatFromInt(self.screen_width);
        const height_f64: f64 = @floatFromInt(self.screen_height);

        const norm_x: f64 = screen_point.x / width_f64;
        const norm_y: f64 = screen_point.y / height_f64;

        const world_x = self.data_min_x + norm_x * x_range;
        const world_y = self.data_min_y + norm_y * y_range;

        return .{
            .x = world_x,
            .y = world_y,
        };
    }

    fn getBoundsImpl(ptr: *anyopaque) core.Bounds2D {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        return .{
            .min_x = self.data_min_x,
            .min_y = self.data_min_y,
            .max_x = self.data_max_x,
            .max_y = self.data_max_y,
        };
    }
    fn setBoundsImpl(ptr: *anyopaque, bounds: core.Bounds2D) void {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        self.data_min_x = bounds.min_x;
        self.data_min_y = bounds.min_y;
        self.data_max_x = bounds.max_x;
        self.data_max_y = bounds.max_y;
    }
};
