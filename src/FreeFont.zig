const std = @import("std");
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
    FailedToSetPixelSized,
    FailedToLoadGlyph,
    FailedToLoadChar,
    //FailedToDeinitFace,
    //FailedToDeinitFreeTypeLibrary,
};

pub const FT_Library = FT.FT_Library;
pub const FT_FACE = FT.FT_Face;
pub const FT_LOAD_RENDER = FT.FT_LOAD_RENDER;
pub fn FT_Init_FreeType(alibrary: [*c]FT_Library) !void {
    const ret: FT.FT_Error = FT.FT_Init_FreeType(alibrary);
    if (ret != 0) return FreeTypeError.InitFreeTypeFailure;
}
pub fn FT_New_Face(library: FT_Library, filepathname: [*c]const u8, face_index: usize, aface: [*c]FT.FT_Face) !void {
    const _face_index: FT.FT_Long = @intCast(face_index);
    const ret: FT.FT_Error = FT.FT_New_Face(library, filepathname, _face_index, aface);
    if (ret != 0) return FreeTypeError.FailedToLoadFont;
}
pub fn FT_Set_Pixel_Sizes(face: FT_FACE, pixel_width: usize, pixel_height: usize) !void {
    const ret: FT.FT_Error = FT.FT_Set_Pixel_Sizes(face, @intCast(pixel_width), @intCast(pixel_height));
    if (ret != 0) return FreeTypeError.FailedToSetPixelSized;
}
pub fn FT_Load_Char(face: FT_FACE, char: usize, load_flags: FT.FT_Int32) !void {
    if (FT.FT_Load_Char(face, @intCast(char), load_flags) != 0) return FreeTypeError.FailedToLoadChar;
}
pub fn FT_Done_Face(face: FT_FACE) void {
    _ = FT.FT_Done_Face(face);
}
pub fn FT_Done_FreeType(library: FT_Library) void {
    _ = FT.FT_Done_FreeType(library);
}
