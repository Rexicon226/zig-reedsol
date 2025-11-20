const std = @import("std");
const gf = @import("gf.zig");

pub fn addMod(x: u32, y: u32) u16 {
    const dif = x + gf.modulus - y;
    return @truncate(dif + (dif >> 16));
}

pub fn xor(a: []const []u8, b: []const []u8) void {
    std.debug.assert(a.len == b.len);
    std.debug.assert(a.len >= 0);
    std.debug.assert(a[0].len == 64);
    std.debug.assert(b[0].len == 64);
    for (a, b) |ac, bc| {
        const c: @Vector(64, u8) = ac[0..64].*;
        const d: @Vector(64, u8) = bc[0..64].*;
        ac[0..64].* = c ^ d;
    }
}
