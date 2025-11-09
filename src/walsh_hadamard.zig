const gf = @import("gf.zig");
const utils = @import("utils.zig");

pub fn fwht(data: *[gf.order]u16, m_truncated: u64) void {
    var dist: u64 = 1;
    var dist_4: u64 = 4;

    while (dist_4 <= gf.order) {
        var r: u64 = 0;
        while (r < m_truncated) : (r += dist_4) {
            for (r..r + dist) |offset| {
                fwht4(data, @truncate(offset), @truncate(dist));
            }
        }
        dist = dist_4;
        dist_4 <<= 2;
    }
}

fn fwht4(data: *[gf.order]u16, offset: u16, dist: u16) void {
    const offset_u64: u64 = @intCast(offset);
    const dist_u64: u64 = @intCast(dist);

    const x0: u64 = offset_u64 + dist_u64 * 0;
    const x1: u64 = offset_u64 + dist_u64 * 1;
    const x2: u64 = offset_u64 + dist_u64 * 2;
    const x3: u64 = offset_u64 + dist_u64 * 3;

    const s0, const d0 = fwht2(data[x0], data[x1]);
    const s1, const d1 = fwht2(data[x2], data[x3]);
    const s2, const d2 = fwht2(s0, s1);
    const s3, const d3 = fwht2(d0, d1);

    data[x0] = s2;
    data[x1] = s3;
    data[x2] = d2;
    data[x3] = d3;
}

fn fwht2(a: u16, b: u16) struct { u16, u16 } {
    const sum = utils.addMod(a, b);
    const dif = utils.subMod(a, b);

    return .{ sum, dif };
}
