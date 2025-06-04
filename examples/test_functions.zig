const std = @import("std");
const MathError = error{
    MismatchedLengths,
};
pub fn sin(amplitue: ?f64, x: []f64, y: []f64) !void {
    const a: f64 = amplitue orelse 1;
    if (x.len != y.len) return MathError.MismatchedLengths;
    for (0..x.len) |i| {
        y[i] = a * std.math.sin(x[i]);
    }
}
pub fn cos(amplitue: ?f64, x: []f64, y: []f64) !void {
    const a: f64 = amplitue orelse 1;
    if (x.len != y.len) return MathError.MismatchedLengths;
    for (0..x.len) |i| {
        y[i] = a * std.math.cos(x[i] + (std.math.pi / 2.0));
    }
}
pub fn tan(amplitue: ?f64, x: []f64, y: []f64) !void {
    const a: f64 = amplitue orelse 1;
    if (x.len != y.len) return MathError.MismatchedLengths;
    for (0..x.len) |i| {
        y[i] = a * std.math.tan(x[i]);
    }
}

pub fn z3(x: []f64, y: []f64) !void {
    if (x.len != y.len) return MathError.MismatchedLengths;
    for (0..x.len) |i| {
        y[i] = x[i] * x[i] * x[i] + 5 * x[i];
    }
}
pub fn sombrero(x: []const f64, y: []f64) MathError!void {
    if (x.len != y.len) return MathError.MismatchedLengths;

    for (x, 0..) |val, i| {
        const xx = val * val;
        y[i] = if (xx == 0.0) 1.0 else std.math.sin(xx) / xx;
    }
}
