//! AVX512 GFNI optimized engine for specifically 32 data and parity shards
//! (common usecase in Solana shard network).

const std = @import("std");
const builtin = @import("builtin");

const Shards = @import("../root.zig").Shards;

const V = @Vector(32, u8);

pub fn encode(shred_size: u64, data: []const []const u8, parity: []const []u8) void {
    std.debug.assert(shred_size >= 32);
    std.debug.assert(data.len == 32);
    std.debug.assert(parity.len == 32);

    var count: usize = 0;
    var registers: [32]V = undefined;
    while (true) {
        inline for (0..32) |i| registers[i] = data[i][count..][0..32].*;

        inline for (0..15) |i| ifft(
            registers[2 * i + 0],
            registers[2 * i + 1],
            2 * i,
        );

        inline for (0..7, .{ 0, 6, 28, 26, 120, 126, 100 }) |i, k| ifft(
            registers[4 * i + 0],
            registers[4 * i + 2],
            k,
        );

        ifft(registers[0], registers[4], 0);
        ifft(registers[8], registers[12], 22);
        ifft(registers[16], registers[20], 97);
        ifft(registers[0], registers[8], 0);
        ifft(registers[4], registers[12], 0);
        ifft(registers[2], registers[6], 0);
        ifft(registers[10], registers[14], 22);
        ifft(registers[18], registers[22], 97);
        ifft(registers[2], registers[10], 0);
        ifft(registers[6], registers[14], 0);
        ifft(registers[1], registers[3], 0);
        ifft(registers[5], registers[7], 6);
        ifft(registers[9], registers[11], 28);
        ifft(registers[13], registers[15], 26);
        ifft(registers[17], registers[19], 120);
        ifft(registers[21], registers[23], 126);
        ifft(registers[25], registers[27], 100);
        ifft(registers[1], registers[5], 0);
        ifft(registers[9], registers[13], 22);
        ifft(registers[17], registers[21], 97);
        ifft(registers[1], registers[9], 0);
        ifft(registers[5], registers[13], 0);
        ifft(registers[3], registers[7], 0);
        ifft(registers[11], registers[15], 22);
        ifft(registers[19], registers[23], 97);
        ifft(registers[3], registers[11], 0);
        ifft(registers[7], registers[15], 0);

        // spill 14 reload 31

        ifft(registers[30], registers[31], 30);
        ifft(registers[28], registers[30], 98);
        ifft(registers[24], registers[28], 119);
        ifft(registers[16], registers[24], 11);
        ifft(registers[0], registers[16], 0);
        ifft(registers[8], registers[24], 0);
        ifft(registers[20], registers[28], 11);
        ifft(registers[4], registers[20], 0);
        ifft(registers[12], registers[28], 0);
        ifft(registers[26], registers[30], 119);
        ifft(registers[18], registers[26], 11);
        ifft(registers[2], registers[18], 0);
        ifft(registers[10], registers[26], 0);
        ifft(registers[22], registers[30], 11);
        ifft(registers[6], registers[22], 0);
        ifft(registers[29], registers[31], 98);
        ifft(registers[25], registers[29], 119);
        ifft(registers[17], registers[25], 11);
        ifft(registers[1], registers[17], 0);
        ifft(registers[9], registers[25], 0);
        ifft(registers[21], registers[29], 11);
        ifft(registers[5], registers[21], 0);
        ifft(registers[13], registers[29], 0);
        ifft(registers[27], registers[31], 119);
        ifft(registers[19], registers[27], 11);
        ifft(registers[3], registers[19], 0);
        ifft(registers[11], registers[27], 0);
        ifft(registers[23], registers[31], 11);
        ifft(registers[7], registers[23], 0);
        ifft(registers[15], registers[31], 0);

        // spill 31 reload 14

        ifft(registers[14], registers[30], 0);

        fft(registers[0], registers[16], 71);
        fft(registers[8], registers[24], 71);
        fft(registers[0], registers[8], 174);
        fft(registers[16], registers[24], 165);
        fft(registers[4], registers[20], 71);
        fft(registers[12], registers[28], 71);
        fft(registers[4], registers[12], 174);
        fft(registers[20], registers[28], 165);
        fft(registers[0], registers[4], 38);
        fft(registers[8], registers[12], 48);
        fft(registers[16], registers[20], 71);
        fft(registers[24], registers[28], 81);
        fft(registers[2], registers[18], 71);
        fft(registers[10], registers[26], 71);
        fft(registers[2], registers[10], 174);
        fft(registers[18], registers[26], 165);
        fft(registers[6], registers[22], 71);
        fft(registers[14], registers[30], 71);
        fft(registers[6], registers[14], 174);
        fft(registers[22], registers[30], 165);
        fft(registers[2], registers[6], 38);
        fft(registers[10], registers[14], 48);
        fft(registers[18], registers[22], 71);
        fft(registers[26], registers[30], 81);
        fft(registers[0], registers[2], 237);
        fft(registers[4], registers[6], 235);
        fft(registers[8], registers[10], 241);
        fft(registers[12], registers[14], 247);
        fft(registers[16], registers[18], 149);
        fft(registers[20], registers[22], 147);
        fft(registers[24], registers[26], 137);
        fft(registers[28], registers[30], 143);
        fft(registers[1], registers[17], 71);
        fft(registers[9], registers[25], 71);
        fft(registers[1], registers[9], 174);
        fft(registers[17], registers[25], 165);
        fft(registers[5], registers[21], 71);
        fft(registers[13], registers[29], 71);
        fft(registers[5], registers[13], 174);
        fft(registers[21], registers[29], 165);
        fft(registers[1], registers[5], 38);
        fft(registers[9], registers[13], 48);
        fft(registers[17], registers[21], 71);
        fft(registers[25], registers[29], 81);
        fft(registers[3], registers[19], 71);
        fft(registers[11], registers[27], 71);
        fft(registers[3], registers[11], 174);
        fft(registers[19], registers[27], 165);
        fft(registers[7], registers[23], 71);

        // spill 14 reload 31

        fft(registers[15], registers[31], 71);
        fft(registers[7], registers[15], 174);
        fft(registers[23], registers[31], 165);
        fft(registers[3], registers[7], 38);
        fft(registers[11], registers[15], 48);
        fft(registers[19], registers[23], 71);
        fft(registers[27], registers[31], 81);
        fft(registers[1], registers[3], 237);
        fft(registers[5], registers[7], 235);
        fft(registers[9], registers[11], 241);
        fft(registers[13], registers[15], 247);
        fft(registers[17], registers[19], 149);
        fft(registers[21], registers[23], 147);
        fft(registers[25], registers[27], 137);
        fft(registers[29], registers[31], 143);

        inline for (0..16) |i| {
            const a = i * 2;
            const b = a + 1;
            const k = 32 + a;
            fft(registers[a], registers[b], k);
            parity[a][count..][0..32].* = registers[a];
            parity[b][count..][0..32].* = registers[b];
        }

        count += 32;
        if (count == 1024) break;
        count = @min(count, shred_size - 32);
    }
}

const POLY = 0x11D;

fn mul(x: u8, y: u8) u8 {
    var a: u32 = x;
    var b: u32 = y;
    var res: u32 = 0;
    for (0..8) |_| {
        if (b & 1 != 0) res ^= a;
        const carry = a & 0x80 != 0;
        a <<= 1;
        if (carry) a ^= POLY;
        a &= 0xFF;
        b >>= 1;
    }
    return res;
}

const table = t: {
    @setEvalBranchQuota(100_000);
    var output: [256][4]u64 = undefined;
    for (0..256) |c| {
        var t: [8]u8 = undefined;
        for (0..8) |j| t[j] = mul(c, 1 << j);
        var w: u64 = 0;
        for (0..64) |i| {
            const val = t[i % 8];
            if (val & (1 << 7 - i / 8) != 0) w |= 1 << i;
        }
        output[c] = @splat(w);
    }
    break :t output;
};

inline fn ifft(reg0: V, reg1: V, c: comptime_int) void {
    if (c == 0) {
        asm volatile ("vpxord %[reg0], %[reg1], %[reg1]"
            :
            : [reg0] "x" (reg0),
              [reg1] "x" (reg1),
        );
    } else {
        _ = asm volatile (
            \\vpxord %[reg0], %[reg1], %[reg1]
            \\vgf2p8affineqb $0x00, %[c], %[reg1], %[scratch]
            : [scratch] "=x" (-> V),
            : [reg0] "x" (reg0),
              [reg1] "x" (reg1),
              [c] "rm" (@as(@Vector(4, u64), table[c])), // need rm for LLVM to emit memop version
        );
    }
}

inline fn fft(reg0: V, reg1: V, c: comptime_int) void {
    _ = asm volatile (
        \\vgf2p8affineqb $0x00, %[c], %[reg1], %[scratch]
        \\vpxord %[reg0], %[scratch], %[reg0]
        \\vpxord %[reg1], %[reg0], %[reg1]
        : [scratch] "=x" (-> V),
        : [reg0] "x" (reg0),
          [reg1] "x" (reg1),
          [c] "rm" (@as(@Vector(4, u64), table[c])), // need rm for LLVM to emit memop version
    );
}
