const std = @import("std");
const FreeFont = @import("FreeFont.zig");
const stf = @cImport(@cInclude("../deps/stb_truetype.h"));
const FT = @cImport(
    {
        @cInclude("ft2build.h");
        @cInclude("freetype2/freetype/freetype.h");
        @cDefine("FT_FREETYPE_H", {});
    },
);
const FreeTypeError = error{
    InitFreeTypeFailure,
    FailedToLoadFont,
    FailedToLoadGlyph,
};

pub const Font = struct {
    ft: FT.FT_Library,
    face: FT.FT_Face,
    font_size: usize,
    allocator: std.mem.Allocator,

    fn create(allocator: std.mem.Allocator) !*@This() {
        const font = try allocator.create(@This());
        font.* = .{
            .ft = undefined,
            .face = undefined,
            .font_size = undefined,
            .allocator = allocator,
        };
        return font;
    }
    fn destory(self: *@This()) void {
        self.allocator.destroy(self);
    }
    pub fn init(allocator: std.mem.Allocator, filepathname: [*c]const u8) !*@This() {
        var font = try @This().create(allocator);
        errdefer allocator.destroy(font);
        try FreeFont.FT_Init_FreeType(&font.ft);
        try FreeFont.FT_New_Face(font.ft, filepathname, 0, &font.face);
        return font;
    }
    pub fn deinit(self: *@This()) void {
        FreeFont.FT_Done_Face(self.face);
        FreeFont.FT_Done_FreeType(self.ft);
        self.destory();
    }
    fn drawChar(self: *@This(), cx: usize, cy: usize, comptime buffType: type, buff: []buffType, bw: usize, bh: usize) !void {
        const face = self.*.face;
        const bmp: FT.FT_Bitmap = face.*.glyph.*.bitmap;
        const bmp_rows: usize = @intCast(bmp.rows);
        const bmp_width: usize = @intCast(bmp.width);
        const bmp_pitch: usize = @intCast(bmp.pitch);

        const x0: usize = cx + @as(usize, @intCast(face.*.glyph.*.bitmap_left));
        const y0: isize = @as(isize, @intCast(cy)) - face.*.glyph.*.bitmap_top;

        for (0..bmp_rows) |y| {
            for (0..bmp_width) |x| {
                const gray: u8 = bmp.buffer[y * bmp_pitch + x];
                const px = x0 + x;
                const py = y0 + @as(isize, @intCast(y));
                if (px < bw and py >= 0 and @as(usize, @intCast(py)) < bh) {
                    const alpha = buff[@as(usize, @intCast(py)) * bw + px][3];
                    buff[@as(usize, @intCast(py)) * bw + px] = .{ gray, gray, gray, alpha };
                }
            }
        }
    }

    pub fn drawText(
        self: *@This(),
        font_size: usize,
        x0: usize,
        y0: usize,
        comptime buffType: type,
        buff: []buffType,
        bw: usize,
        bh: usize,
        text: []const u8,
    ) !void {
        const face = self.*.face;
        var text_width: usize = 0;
        try FreeFont.FT_Set_Pixel_Sizes(face, 0, font_size);
        for (text) |char| {
            try FreeFont.FT_Load_Char(face, char, FT.FT_LOAD_RENDER);
            text_width += @intCast(face.*.glyph.*.advance.x >> 6);
        }
        if (text_width > bw) return error.TextTooWideForBuffer;

        var pen_x: isize = @as(isize, @intCast(((2 * x0) - text_width) / 2));
        const pen_y: isize = @as(isize, @intCast(y0));

        for (text) |char| {
            try FreeFont.FT_Load_Char(face, char, FT.FT_LOAD_RENDER);
            try self.*.drawChar(@intCast(pen_x), @intCast(pen_y), buffType, buff, bw, bh);
            pen_x += @intCast(face.*.glyph.*.advance.x >> 6);
        }
    }
};
