const std = @import("std");
pub const color = @import("color.zig");
pub const Canvas = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    const VTable = struct {
        drawPixel: *const fn (ptr: *anyopaque, x: u32, y: u32, c: color.Color) void,
        drawLine: *const fn (ptr: *anyopaque, x0: u32, y0: u32, x1: u32, y1: u32, thickness: u32, c: color.Color) void,
        drawRectangle: *const fn (ptr: *anyopaque, cx: u32, cy: u32, width: u32, height: u32, c: color.Color) void,
        drawCircle: *const fn (ptr: *anyopaque, cx: u32, cy: u32, radius: u32, c: color.Color) void,
        clear: *const fn (ptr: *anyopaque, c: color.Color) void,
        getDimensions: *const fn (ptr: *anyopaque) Dim,
    };

    pub fn drawPixel(self: @This(), x: u32, y: u32, c: color.Color) void {
        self.vtable.drawPixel(self.ptr, x, y, c);
    }
    pub fn drawLine(self: @This(), x0: u32, y0: u32, x1: u32, y1: u32, thickness: u32, c: color.Color) void {
        self.vtable.drawLine(self.ptr, x0, y0, x1, y1, thickness, c);
    }
    pub fn drawRectangle(self: @This(), cx: u32, cy: u32, width: u32, height: u32, c: color.Color) void {
        self.vtable.drawRectangle(self.ptr, cx, cy, width, height, c);
    }
    pub fn drawCircle(self: @This(), cx: u32, cy: u32, radius: u32, c: color.Color) void {
        self.vtable.drawCircle(self.ptr, cx, cy, radius, c);
    }
    pub fn clear(self: @This(), c: color.Color) void {
        self.vtable.clear(self.ptr, c);
    }
    pub fn getDimensions(self: @This()) Dim {
        self.vtable.getDimensions(self.ptr);
    }
};

pub const CoordianteTransform = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        worldToScreen: *const fn (ptr: *anyopaque, world_point: Point2D) Point2D,
        screenToWorld: *const fn (ptr: *anyopaque, screen_point: Point2D) Point2D,
        setBounds: *const fn (ptr: *anyopaque, bounds: Bounds2D) void,
        getbounds: *const fn (ptr: *anyopaque) Bounds2D,
    };

    pub fn worldToScreen(self: @This(), world_point: Point2D) Point2D {
        return self.vtable.worldToScreen(self.ptr, world_point);
    }
    pub fn screenToWorld(self: @This(), world_point: Point2D) Point2D {
        return self.vtable.screenToWorld(self.ptr, world_point);
    }
    pub fn setBounds(self: @This(), bounds: Bounds2D) void {
        self.vtable.setBounds(self.ptr, bounds);
    }
    pub fn getBounds(self: @This()) Bounds2D {
        return self.vtable.getbounds(self.ptr);
    }
};

pub const Point2D = struct {
    x: f64,
    y: f64,
};
pub const Dim = struct { width: u32, height: u32 };
pub const Bounds2D = struct {
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,

    pub fn width(self: @This()) f64 {
        return (self.max_x - self.min_x);
    }
    pub fn height(self: @This()) f64 {
        return (self.max_y - self.min_y);
    }
};

pub const Padding = struct {
    top: u32,
    right: u32,
    bottom: u32,
    left: u32,
    pub fn uniform(value: u32) @This() {
        return .{
            .top = value,
            .bottom = value,
            .right = value,
            .left = value,
        };
    }
};

pub const RenderContext = struct {
    canvas: Canvas,
    transform: CoordianteTransform,
    clip_bounds: ?Bounds2D = null,

    pub fn drawWorldLine(self: @This(), start: Point2D, end: Point2D, thickness: u32, c: color.Color) void {
        const start_screen = self.transform.worldToScreen(start);
        const end_screen = self.transform.worldToScreen(end);

        const x0: u32 = @intFromFloat(start_screen.x);
        const y0: u32 = @intFromFloat(start_screen.y);
        const x1: u32 = @intFromFloat(end_screen.x);
        const y1: u32 = @intFromFloat(end_screen.y);
        self.canvas.drawLine(x0, y0, x1, y1, thickness, c);
    }
    pub fn drawWorldCircle(self: @This(), center: Point2D, radius: f64, c: color.Color) void {
        const screen_center = self.transform.worldToScreen(center);

        const bounds = self.transform.getBounds();
        const canvas_dim = self.canvas.getDimensions();
        const scale_x = @as(f64, @floatFromInt(canvas_dim.width)) / bounds.width();
        const screen_radius = @as(u32, @intFromFloat(radius * scale_x));
        self.canvas.drawCircle(screen_center.x, screen_center.y, screen_radius, c);
    }
};

pub const Layer = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        render: *const fn (ptr: *anyopaque, ctx: RenderContext) void,
        getBounds: *const fn (ptr: *anyopaque) ?Bounds2D,
        setVisible: *const fn (ptr: *anyopaque, visible: bool) void,
        isVisible: *const fn (ptr: *anyopaque) bool,
    };

    pub fn render(self: @This(), ctx: RenderContext) void {
        self.vtable.render(self.ptr, ctx);
    }

    pub fn getBounds(self: @This()) ?Bounds2D {
        return self.vtable.getBounds(self.ptr);
    }
    pub fn setVisible(self: @This(), visible: bool) void {
        self.vtable.setVisible(self.ptr, visible);
    }
    pub fn isVisible(self: @This()) bool {
        self.vtable.isVisible(self.ptr);
    }
};

pub const LinePlotLayer = struct {
    points: std.ArrayList(Point2D),
    c: color.Color,
    thickness: u32,
    visible: bool,
    pub fn init(allocator: std.mem.Allocator, c: color.Color, thickness: u32) @This() {
        return .{
            .points = std.ArrayList(Point2D).init(allocator),
            .c = c,
            .thickness = thickness,
            .visible = true,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.points.deinit();
    }
    pub fn addPoint(self: *@This(), point: Point2D) !void {
        try self.points.append(point);
    }
    pub fn setData(self: *@This(), x_data: []f64, y_data: []const f64) !void {
        if (x_data.len != y_data.len) return error.MismatchedDataLenght;
        self.points.clearRetainingCapacity();
        for (x_data, y_data) |x, y| {
            try self.points.append(.{
                .x = x,
                .y = y,
            });
        }
    }
    fn renderImpl(ptr: *anyopaque, ctx: RenderContext) void {
        const self: *@This() = @ptrCast(@alignCast(ptr));

        for (0..self.points.items.len - 1) |i| {
            ctx.drawWorldLine(self.points.items[i], self.points.items[i + 1], self.thickness, self.c);
        }
    }
    fn getBoundsImpl(ptr: *anyopaque) ?Bounds2D {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        if (self.points.items.len == 0) return null;

        var bounds = Bounds2D{
            .min_x = self.points.items[0].x,
            .min_y = self.points.items[0].y,
            .max_x = self.points.items[0].x,
            .max_y = self.points.items[0].y,
        };

        for (self.points.items[1..]) |point| {
            bounds.min_x = @min(bounds.min_x, point.x);
            bounds.min_y = @min(bounds.min_y, point.y);
            bounds.max_x = @max(bounds.max_x, point.x);
            bounds.max_y = @max(bounds.max_y, point.y);
        }
        return bounds;
    }
    pub fn setVisibleImpl(ptr: *anyopaque, visible: bool) void {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        self.visible = visible;
    }
    pub fn isVisibleImpl(ptr: *anyopaque) bool {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        return self.visible;
    }

    pub fn asLayer(self: *@This()) Layer {
        return Layer{ .ptr = self, .vtable = &.{
            .render = renderImpl,
            .getBounds = getBoundsImpl,
            .setVisible = setVisibleImpl,
            .isVisible = isVisibleImpl,
        } };
    }
};
pub const ScatterPlotLayer = struct {
    points: std.ArrayList(Point2D),
    c: color.Color,
    radius: u32,
    visible: bool,

    pub fn init(allocator: std.mem.Allocator, c: color, radius: u32) @This() {
        return .{
            .points = std.ArrayList(Point2D).init(allocator),
            .c = c,
            .radius = radius,
            .visible = true,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.points.deinit();
    }
    pub fn addPoint(self: @This(), point: Point2D) !void {
        try self.points.append(point);
    }
    pub fn setData(self: @This(), x_data: []const u8, y_data: []const u8) !void {
        if (x_data.len != y_data.len) return error.MismatchedDataLenght;
        self.points.clearRetainingCapacity();
        for (x_data, y_data) |x, y| {
            try self.points.append(.{
                .x = x,
                .y = y,
            });
        }
    }
    fn renderImpl(ptr: *anyopaque, ctx: RenderContext) void {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        const points = self.points;
        for (0..points.items.len - 1) |i| {
            ctx.drawWorldCircle(points[i], points[i + 1], self.radius, self.c);
        }
    }
    fn getBoundsImpl(ptr: *anyopaque) ?Bounds2D {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        const points = self.points;
        if (points.items.len == 0) return null;

        var bounds = Bounds2D{
            .min_x = points[0].x,
            .min_y = points[0].y,
            .max_x = points[0].x,
            .max_y = points[0].y,
        };

        for (points[1..]) |point| {
            bounds.min_x = @min(bounds.min_x, point.x);
            bounds.min_y = @min(bounds.min_y, point.y);
            bounds.max_x = @max(bounds.max_x, point.x);
            bounds.max_y = @max(bounds.max_y, point.y);
        }
        return bounds;
    }
    pub fn setVisibleImpl(ptr: *anyopaque, visible: bool) bool {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        self.visible = visible;
    }
    pub fn isVisibleImpl(ptr: *anyopaque) bool {
        const self: *@This() = @ptrCast(@alignCast(ptr));
        return self.visible;
    }

    pub fn asLayer(self: *@This()) Layer {
        return Layer{ .ptr = self, .vtable = &.{
            .render = renderImpl,
            .getBounds = getBoundsImpl,
            .setVisible = setVisibleImpl,
            .isVisible = isVisibleImpl,
        } };
    }
};

pub const Plot = struct {
    layers: std.ArrayList(Layer),
    canvas: Canvas,
    transform: CoordianteTransform,
    bgc: color.Color,
    auto_bounds: bool,
    padding: Padding,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, canvas: Canvas, transform: CoordianteTransform) @This() {
        return @This(){
            .layers = std.ArrayList(Layer).init(allocator),
            .canvas = canvas,
            .transform = transform,
            .bgc = color.getColor(.white),
            .padding = Padding.uniform(50),
            .allocator = allocator,
            .auto_bounds = true,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.layers.deinit();
    }

    pub fn addLayers(self: *@This(), layer: Layer) !void {
        try self.layers.append(layer);
        if (self.auto_bounds) {
            self.updateBounds();
        }
    }
    pub fn removeLayer(self: *@This(), index: usize) void {
        _ = self.layers.swapRemove(index);
        if (self.auto_bounds) {
            self.updateBounds();
        }
    }

    pub fn render(self: *@This()) void {
        self.canvas.clear(self.bgc);
        const ctx = RenderContext{
            .canvas = self.canvas,
            .transform = self.transform,
        };

        for (self.layers.items) |layer| {
            layer.render(ctx);
        }
    }

    pub fn updateBounds(self: *@This()) void {
        var combined_bounds: ?Bounds2D = null;

        for (self.layers.items) |layer| {
            if (layer.getBounds()) |bounds| {
                if (combined_bounds) |*cb| {
                    cb.min_x = @min(cb.min_x, bounds.min_x);
                    cb.min_y = @min(cb.min_y, bounds.min_y);
                    cb.max_x = @max(cb.max_x, bounds.max_x);
                    cb.max_y = @max(cb.max_y, bounds.max_y);
                } else {
                    combined_bounds = bounds;
                }
            }
        }
        if (combined_bounds) |bounds| {
            const x_range = bounds.width();
            const y_range = bounds.height();

            const x_pad = x_range * 0.1;
            const y_pad = y_range * 0.1;

            const padded_bounds = Bounds2D{
                .min_x = bounds.min_x - x_pad,
                .min_y = bounds.min_y - y_pad,
                .max_x = bounds.max_x + x_pad,
                .max_y = bounds.max_y + y_pad,
            };
            self.transform.setBounds(padded_bounds);
        }
    }

    pub fn setounds(self: *@This(), bounds: Bounds2D) void {
        self.auto_bounds = false;
        self.transform.setBounds(bounds);
    }

    pub fn enableautoBounds(self: *Plot) void {
        self.auto_bounds = true;
        self.updateBounds();
    }
};
