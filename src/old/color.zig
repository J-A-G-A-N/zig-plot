const std = @import("std");
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};
pub const Colors = enum {
    black,
    white,
    red,
    green,
    blue,
    yellow,
    random,
};

pub fn getColor(c: Colors) Color {
    return switch (c) {
        .black => Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
        .white => Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
        .red => Color{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .green => Color{ .r = 0, .g = 255, .b = 0, .a = 255 },
        .blue => Color{ .r = 0, .g = 0, .b = 255, .a = 255 },
        .yellow => Color{ .r = 255, .g = 255, .b = 0, .a = 255 },
        .random => getRandom_color(),
    };
}
pub fn getRandom_color() Color {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    var rng = prng.random();
    const r = rng.intRangeAtMost(u8, 100, 255);
    const g = rng.intRangeAtMost(u8, 100, 255);
    const b = rng.intRangeAtMost(u8, 100, 255);
    const a = 255;
    return .{
        .r = r,
        .g = g,
        .b = b,
        .a = a,
    };
}
