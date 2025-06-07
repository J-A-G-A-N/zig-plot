const std = @import("std");
const color = @import("color.zig");
const stt = @cImport(@cInclude("../deps/stb_truetype.h"));

pub const FontError = error{FailedToInitFont};

pub const Font = struct {
    font_info: stt.stbtt_fontinfo,
    font_data: []const u8,
    allocator: std.mem.Allocator,

    fn create(allocator: std.mem.Allocator) !*@This() {
        const font = try allocator.create(@This());
        return font;
    }

    pub fn init(allocator: std.mem.Allocator, font_file_path: []const u8) !*@This() {
        const cwd = std.fs.cwd();
        var font = try create(allocator);
        const font_file = try cwd.openFile(font_file_path, .{});
        defer font_file.close();
        const font_file_stat = try font_file.stat();
        font.font_data = try font_file.readToEndAlloc(allocator, font_file_stat.size);
        font.allocator = allocator;
        std.debug.print("font.font_data: {any}\n", .{@TypeOf(font.font_data)});
        const init_of = stt.stbtt_InitFont(&font.font_info, font.font_data.ptr, 0);
        if (init_of != 1) return FontError.FailedToInitFont;
        return font;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.font_data);
        self.allocator.destroy(self);
    }

    fn drawChar(self: *@This(), buff: []color.Color, codepoint: c_int, pen_x: f32, baseline_y: f32, bw: u32, bh: u32, scale: f32, c: color.Color) !void {
        var bitmap_width: c_int = undefined;
        var bitmap_height: c_int = undefined;
        const bw_usize: usize = @intCast(bw);
        const bh_usize: usize = @intCast(bh);
        var xoff: c_int = undefined;
        var yoff: c_int = undefined;

        const bitmap: [*c]u8 = stt.stbtt_GetCodepointBitmap(&self.font_info, scale, scale, codepoint, &bitmap_width, &bitmap_height, &xoff, &yoff);
        defer stt.stbtt_FreeBitmap(bitmap, null);

        // Position the character correctly relative to the pen position and baseline
        const x0: c_int = @as(c_int, @intFromFloat(pen_x)) + xoff;
        const y0: c_int = @as(c_int, @intFromFloat(baseline_y)) + yoff;

        var y: c_int = 0;
        while (y < bitmap_height) : (y += 1) {
            var x: c_int = 0;
            while (x < bitmap_width) : (x += 1) {
                const idx = @as(usize, @intCast(y * bitmap_width + x));
                const value = bitmap[idx];
                if (value == 0) continue;

                const px: i32 = x0 + x;
                const py: i32 = y0 + y;

                // Bounds checking
                if (px >= 0 and px < @as(i32, @intCast(bw_usize)) and py >= 0 and py < @as(i32, @intCast(bh_usize))) {
                    const index: usize = @as(usize, @intCast(py)) * bw_usize + @as(usize, @intCast(px));
                    buff[index] = blendColor(buff[index], c, value);
                }
            }
        }
    }

    fn blendColor(bg: color.Color, fg: color.Color, alpha: u8) color.Color {
        const a: f32 = @as(f32, @floatFromInt(alpha)) / 255.0;
        const inv_a: f32 = 1.0 - a;

        return color.Color{
            .r = @intFromFloat(@as(f32, @floatFromInt(fg.r)) * a + @as(f32, @floatFromInt(bg.r)) * inv_a),
            .g = @intFromFloat(@as(f32, @floatFromInt(fg.g)) * a + @as(f32, @floatFromInt(bg.g)) * inv_a),
            .b = @intFromFloat(@as(f32, @floatFromInt(fg.b)) * a + @as(f32, @floatFromInt(bg.b)) * inv_a),
            .a = 255, // Keep it opaque, or use bg.a if blending with transparency
        };
    }

    pub fn drawText(
        self: *@This(),
        buff: []color.Color,
        text: []const u8,
        font_size: f32,
        cx: u32,
        cy: u32,
        bw: u32,
        bh: u32,
        c: color.Color,
    ) !void {
        const scale: f32 = stt.stbtt_ScaleForPixelHeight(&self.font_info, font_size);

        // Measure total width for centering
        var total_width: f32 = 0.0;
        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            const codepoint: c_int = @intCast(text[i]);
            var advance: c_int = 0;
            var lsb: c_int = 0;
            stt.stbtt_GetCodepointHMetrics(&self.font_info, codepoint, &advance, &lsb);
            total_width += @as(f32, @floatFromInt(advance)) * scale;
        }

        // Get vertical metrics for proper baseline positioning
        var ascent: c_int = 0;
        var descent: c_int = 0;
        var line_gap: c_int = 0;
        stt.stbtt_GetFontVMetrics(&self.font_info, &ascent, &descent, &line_gap);

        // Calculate starting position for centered text
        const x_start: f32 = @as(f32, @floatFromInt(cx)) - total_width / 2.0;
        const baseline_y: f32 = @as(f32, @floatFromInt(cy)) + (@as(f32, @floatFromInt(ascent)) * scale) / 2.0;

        // Render characters along the baseline
        var pen_x: f32 = x_start;
        i = 0;
        while (i < text.len) : (i += 1) {
            const codepoint: c_int = @intCast(text[i]);
            var advance: c_int = 0;
            var lsb: c_int = 0;
            stt.stbtt_GetCodepointHMetrics(&self.font_info, codepoint, &advance, &lsb);

            try self.drawChar(
                buff,
                codepoint,
                pen_x + @as(f32, @floatFromInt(lsb)) * scale, // Add left side bearing
                baseline_y,
                bw,
                bh,
                scale,
                c,
            );

            pen_x += @as(f32, @floatFromInt(advance)) * scale;
        }
    }
};
