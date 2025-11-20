const std = @import("std");
const testing = std.testing;

const reedsol = @import("reedsol");
const encode = reedsol.encode;

test "encode symmetric 8 shards 64 bytes" {
    {
        const SHARD_COUNT = 8;
        const SHARD_BYTES = 64;

        var input: [SHARD_BYTES * SHARD_COUNT]u8 = undefined;
        for (0..input.len) |i| input[i] = @intCast(i % 256);

        const shards: [SHARD_COUNT][SHARD_BYTES]u8 = @bitCast(input);

        var original: [SHARD_COUNT][]const u8 = undefined;
        for (&original, &shards) |*o, *shard| o.* = shard;

        var parity_shards: [SHARD_COUNT][SHARD_BYTES]u8 = undefined;
        var parity: [SHARD_COUNT][]u8 = undefined;
        for (&parity, &parity_shards) |*p, *shard| p.* = shard;

        try encode(
            &original,
            &parity,
            SHARD_BYTES, // we want the same number of input shards as output
        );

        const expected: [SHARD_COUNT][SHARD_BYTES]u8 = @import("./encode_data_8_64.zon");
        for (expected, parity) |e_sh, r_sh| for (e_sh, r_sh) |e, r| try testing.expectEqual(e, r);
    }
}

test "encode symmetric 16 shards 64 bytes" {
    {
        const SHARD_COUNT = 16;
        const SHARD_BYTES = 64;

        var input: [SHARD_BYTES * SHARD_COUNT]u8 = undefined;
        for (0..input.len) |i| input[i] = @intCast(i % 256);

        const shards: [SHARD_COUNT][SHARD_BYTES]u8 = @bitCast(input);

        var original: [SHARD_COUNT][]const u8 = undefined;
        for (&original, &shards) |*o, *shard| o.* = shard;

        var parity_shards: [SHARD_COUNT][SHARD_BYTES]u8 = undefined;
        var parity: [SHARD_COUNT][]u8 = undefined;
        for (&parity, &parity_shards) |*p, *shard| p.* = shard;

        try encode(
            &original,
            &parity,
            SHARD_BYTES, // we want the same number of input shards as output
        );

        const expected: [SHARD_COUNT][SHARD_BYTES]u8 = @import("./encode_data_16_64.zon");
        for (expected, parity) |e_sh, r_sh| for (e_sh, r_sh) |e, r| try testing.expectEqual(e, r);
    }
}

test "encode symmetric 32 shards 64 bytes" {
    {
        const SHARD_COUNT = 32;
        const SHARD_BYTES = 64;

        var input: [SHARD_BYTES * SHARD_COUNT]u8 = undefined;
        for (0..input.len) |i| input[i] = @intCast(i % 256);

        const shards: [SHARD_COUNT][SHARD_BYTES]u8 = @bitCast(input);

        var original: [SHARD_COUNT][]const u8 = undefined;
        for (&original, &shards) |*o, *shard| o.* = shard;

        var parity_shards: [SHARD_COUNT][SHARD_BYTES]u8 = undefined;
        var parity: [SHARD_COUNT][]u8 = undefined;
        for (&parity, &parity_shards) |*p, *shard| p.* = shard;

        try encode(
            &original,
            &parity,
            SHARD_BYTES, // we want the same number of input shards as output
        );

        const expected: [SHARD_COUNT][SHARD_BYTES]u8 = @import("./encode_data_32_64.zon");
        for (expected, parity) |e_sh, r_sh| for (e_sh, r_sh) |e, r| try testing.expectEqual(e, r);
    }
}
