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
        y[i] = a * std.math.cos(x[i]);
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
pub fn z2(x: []f64, y: []f64) !void {
    if (x.len != y.len) return MathError.MismatchedLengths;
    for (0..x.len) |i| {
        y[i] = -(x[i] * x[i]);
    }
}

pub fn sombrero(x: []const f64, y: []f64) MathError!void {
    if (x.len != y.len) return MathError.MismatchedLengths;

    for (x, 0..) |val, i| {
        const xx = val * val;
        y[i] = if (xx == 0.0) 1.0 else std.math.sin(xx) / xx;
    }
}
pub fn gaussianBellCurve(x: []const f64, y: []f64) MathError!void {
    if (x.len != y.len) return MathError.MismatchedLengths;

    for (0..x.len) |i| {
        y[i] = std.math.exp(-(x[i] * x[i]));
    }
}
pub fn xsin(amplitue: ?f64, x: []f64, y: []f64) !void {
    const a: f64 = amplitue orelse 1;
    if (x.len != y.len) return MathError.MismatchedLengths;
    for (0..x.len) |i| {
        y[i] = x[i] * (a * std.math.sin(x[i]));
    }
}

pub fn squareWaveApprox(x: []const f64, y: []f64, harmonics: usize) !void {
    if (x.len != y.len) return error.MismatchedLengths;

    const pi: f64 = std.math.pi;

    for (x, 0..) |xi, i| {
        var sum: f64 = 0;
        var n: usize = 1;
        const max_n = harmonics * 2;

        while (n <= max_n) : (n += 2) {
            sum += std.math.sin(@as(f64, @floatFromInt(n)) * xi) / (@as(f64, @floatFromInt(n)));
        }

        y[i] = (4.0 / pi) * sum;
    }
}
