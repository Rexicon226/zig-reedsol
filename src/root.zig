const std = @import("std");
const builtin = @import("builtin");

const tables = @import("tables");
const util = @import("utilities.zig");
const gf = @import("gf.zig");

const V = @Vector(32, u8);

// self-hosted backend can't compile all the inline asm instructions we use
const has_gfni = builtin.target.cpu.has(.x86, .gfni) and builtin.zig_backend == .stage2_llvm;
pub const Engine = switch (builtin.target.cpu.arch) {
    else => @import("engines/Generic.zig"),
};

/// Encode `original.len` original shards to produce `num_parity_shards` recovery shards.
/// The returned memory is owner by the caller and must be freed on both levels.
///
/// This function isn't nearly as memory efficient as using the Encoder directly, so
/// that is recommended. In that case you would be able to manually handle the lifetimes
/// of the parity shards as needed.
pub fn encode(
    allocator: std.mem.Allocator,
    original: []const []const u8,
    num_parity_shards: u64,
) ![]const []const u8 {
    if (original.len == 0) return error.TooFewOriginalShards;
    const shard_bytes = original[0].len;
    for (original[1..]) |o| if (o.len != shard_bytes) return error.UnequalLengths;

    var encoder: Encoder = try .init(
        allocator,
        original.len,
        num_parity_shards,
        shard_bytes,
    );
    defer encoder.deinit(allocator);

    // populate the data shards
    for (original) |o| try encoder.addDataShard(o);

    // populate the parity shards
    for (0..num_parity_shards) |i| {
        errdefer for (encoder.parity_shards[0..i]) |p| allocator.free(p);
        const shard = try allocator.alloc(u8, shard_bytes);
        try encoder.addParityShard(shard);
    }

    try encoder.encode();

    return try allocator.dupe([]const u8, encoder.parity_shards);
}

// pub fn decode(
//     allocator: std.mem.Allocator,
//     num_data_shards: u64,
//     num_parity_shards: u64,
//     original: []const ?[]const u8,
//     recovery: []const ?[64]u8,
// ) ![]const [64]u8 {
//     const shard_bytes = blk: {
//         for (recovery) |rec| if (rec) |r| break :blk r.len;

//         // no recovery shards
//         var data_received_count: u64 = 0;
//         for (original) |ori| {
//             if (ori != null) data_received_count += 1;
//         }

//         // original data is complete
//         if (data_received_count == num_data_shards) {
//             const result = try allocator.alloc([64]u8, num_data_shards);
//             errdefer allocator.free(result);

//             for (0..num_data_shards) |i| {
//                 @memcpy(&result[i], original[i].?);
//             }

//             return result;
//         } else return error.NotEnoughShards;
//     };

//     var decoder: Decoder = try .init(allocator, num_data_shards, num_parity_shards, shard_bytes);
//     defer decoder.deinit(allocator);

//     for (0..num_data_shards) |i| {
//         if (original[i]) |o| try decoder.addDataShard(i, o);
//     }
//     for (0..num_parity_shards) |i| {
//         if (recovery[i]) |r| try decoder.addRecoveryShard(i, &r);
//     }

//     const data = try decoder.decode();

//     const result = try allocator.alloc([64]u8, num_data_shards);
//     errdefer allocator.free(result);

//     for (0..num_data_shards) |i| {
//         if (original[i]) |o|
//             @memcpy(&result[i], o)
//         else
//             @memcpy(&result[i], &data[decoder.original_base_pos + i]);
//     }

//     return result;
// }

pub const Encoder = struct {
    /// The input data shards. It's required by the caller to keep the memory
    /// alive during the encoding process, since we don't gain ownership of it.
    data_shards: [][]const u8,
    /// The output parity shards. Again, the caller owns the destination pointers,
    /// and is required to make sure they are valid while we write into them.
    parity_shards: [][]u8,
    /// Length of each shard. This applies to both data and parity.
    shard_bytes: usize,
    /// Tracks how many data shards we've "received" through `addDataShard`.
    data_received_count: u64,
    /// Tracks how many parity shards we've "received" through `addParityShard`.
    parity_received_count: u64,

    pub fn init(
        allocator: std.mem.Allocator,
        num_data_shards: u64,
        num_parity_shards: u64,
        shard_bytes: usize,
    ) !Encoder {
        const high_rate = try useHighRate(num_data_shards, num_parity_shards);

        if (high_rate) {
            // shard lengths cannot be 0 nor odd.
            if (shard_bytes == 0 or shard_bytes & 1 != 0) return error.InvalidShardSize;

            const data_shards = try allocator.alloc([]const u8, num_data_shards);
            errdefer allocator.free(data_shards);

            const parity_shards = try allocator.alloc([]u8, num_parity_shards);
            errdefer allocator.free(parity_shards);

            return .{
                .data_shards = data_shards,
                .parity_shards = parity_shards,
                .shard_bytes = shard_bytes,
                .data_received_count = 0,
                .parity_received_count = 0,
            };
        } else {
            @panic("TODO");
        }
    }

    pub fn deinit(e: *Encoder, allocator: std.mem.Allocator) void {
        allocator.free(e.data_shards);
        allocator.free(e.parity_shards);
    }

    pub fn addDataShard(e: *Encoder, original_shard: []const u8) !void {
        if (e.data_received_count == e.data_shards.len) return error.TooManyOriginalShards;
        if (original_shard.len != e.shard_bytes) return error.DifferentShardSize;

        e.data_shards[e.data_received_count] = original_shard;
        e.data_received_count += 1;
    }

    /// The length of the slice must be equal to the shard length, however the contents
    /// can be undefined. It will be overwritten by the encoding process.
    pub fn addParityShard(e: *Encoder, parity_shard: []u8) !void {
        if (e.parity_received_count == e.parity_shards.len) return error.TooManyOriginalShards;
        if (parity_shard.len != e.shard_bytes) return error.DifferentShardSize;

        e.parity_shards[e.parity_received_count] = parity_shard;
        e.parity_received_count += 1;
    }

    pub fn encode(e: *Encoder) !void {
        if (e.data_received_count != e.data_shards.len) return error.TooFewDataShards;

        if (has_gfni and e.data_shards.len == 32 and e.parity_shards.len == 32) {
            @import("engines/avx512.zig").encode(
                e.shard_bytes,
                e.data_shards,
                e.parity_shards,
            );
            return;
        }

        // if (true) @panic("TODO");

        // const chunk_size = try std.math.ceilPowerOfTwo(u64, e.parity_shards.len);

        // first chunk
        // const first_count = @min(e.data_shards.len, chunk_size);
        // e.zero(first_count, chunk_size);
        // Engine.ifft(e.parity_shards, 0, chunk_size, first_count, chunk_size);

        // if (e.num_data_shards > chunk_size) {
        //     // full chunks
        //     var chunk_start = chunk_size;
        //     while (chunk_start + chunk_size < e.num_data_shards) : (chunk_start += chunk_size) {
        //         Engine.ifft(shards, chunk_start, chunk_size, chunk_size, chunk_start + chunk_size);
        //         const s0 = shards.data[0..chunk_size];
        //         const s1 = shards.data[chunk_start * shards.shard_length ..][0..chunk_size];
        //         util.xor(s0, s1);
        //     }

        //     // final partial chunk
        //     const last_count = e.num_data_shards % chunk_size;
        //     if (last_count > 0) {
        //         shards.zero(chunk_start + last_count, shards.data.len);
        //         Engine.ifft(shards, chunk_start, chunk_size, last_count, chunk_start + chunk_size);
        //         const s0 = shards.data[0..chunk_size];
        //         const s1 = shards.data[chunk_start * shards.shard_length ..][0..chunk_size];
        //         util.xor(s0, s1);
        //     }
        // }

        // Engine.fft(shards, 0, chunk_size, e.num_parity_shards, 0);
        // undoLastChunkEncoding(e, 0, e.num_parity_shards);
    }

    // fn insert(e: *Encoder, index: u64, shard: []const u8) void {
    //     std.debug.assert(shard.len % 2 == 0);

    //     const whole_chunk_count = shard.len / 64;
    //     const tail_length = shard.len % 64;

    //     const source_chunks = shard[0 .. shard.len - tail_length];
    //     const dst = s.data[index * s.shard_length ..][0..s.shard_length];
    //     @memcpy(std.mem.sliceAsBytes(dst[0..whole_chunk_count]), source_chunks);

    //     if (tail_length > 0) {
    //         @panic("TODO");
    //     }
    // }

    // /// Zeroes shards from `start_index..end_index`.
    // fn zero(e: *Encoder, start_index: u64, end_index: u64) void {
    //     @memset(e.parity_shards)
    //     const start = start_index * e.shard_bytes;
    //     const end = end_index * s.shard_length;
    //     @memset(std.mem.sliceAsBytes(s.data[start..end]), 0);
    // }
};

// pub const Decoder = struct {
//     num_data_shards: u64,
//     num_parity_shards: u64,
//     shard_bytes: usize,

//     original_base_pos: u64,
//     recovery_base_pos: u64 = 0,

//     data_received_count: u64 = 0,
//     recovery_received_count: u64 = 0,

//     erasures: [gf.order]u16 = @splat(0),

//     received: []bool,
//     shards: Shards,

//     fn init(
//         allocator: std.mem.Allocator,
//         num_data_shards: u64,
//         num_parity_shards: u64,
//         shard_bytes: usize,
//     ) !Decoder {
//         const high_rate = try useHighRate(num_data_shards, num_parity_shards);

//         if (high_rate) {
//             if (shard_bytes == 0 or shard_bytes & 1 != 0) return error.InvalidShardSize;

//             const chunk_size = try std.math.ceilPowerOfTwo(u64, num_parity_shards);
//             const work_count = try std.math.ceilPowerOfTwo(u64, chunk_size + num_data_shards);
//             const shard_bytes_div_ceil = try std.math.divCeil(u64, shard_bytes, 64);

//             var shards: Shards = try .init(
//                 allocator,
//                 work_count,
//                 shard_bytes_div_ceil,
//             );
//             errdefer shards.deinit(allocator);

//             const received = try allocator.alloc(bool, work_count * shard_bytes_div_ceil);
//             errdefer allocator.free(received);
//             @memset(received, false);

//             return .{
//                 .num_data_shards = num_data_shards,
//                 .num_parity_shards = num_parity_shards,
//                 .shard_bytes = shard_bytes,
//                 .original_base_pos = chunk_size,
//                 .received = received,
//                 .shards = shards,
//             };
//         } else {
//             @panic("TODO");
//         }
//     }

//     fn deinit(d: *Decoder, allocator: std.mem.Allocator) void {
//         allocator.free(d.received);
//         d.shards.deinit(allocator);
//     }

//     fn addDataShard(d: *Decoder, index: u64, original_shard: []const u8) !void {
//         const pos = d.original_base_pos + index;

//         if (index >= d.num_data_shards) {
//             return error.InvalidShardIndex;
//         } else if (d.received[pos]) return error.DuplicateShardIndex;
//         if (d.data_received_count == d.num_data_shards) return error.TooManyShards;
//         if (original_shard.len != d.shard_bytes) return error.DifferentShardSize;

//         d.shards.insert(pos, original_shard);
//         d.data_received_count += 1;
//         d.received[pos] = true;
//     }

//     fn addRecoveryShard(d: *Decoder, index: u64, recovery_shard: []const u8) !void {
//         const pos = d.recovery_base_pos + index;

//         if (index >= d.num_parity_shards) {
//             return error.InvalidShardIndex;
//         } else if (d.received[pos]) {
//             return error.DuplicateShardIndex;
//         } else if (d.recovery_received_count == d.num_parity_shards) {
//             return error.TooManyShards;
//         } else if (recovery_shard.len != d.shard_bytes)
//             return error.DifferentShardSize;

//         d.shards.insert(pos, recovery_shard);
//         d.recovery_received_count += 1;
//         d.received[pos] = true;
//     }

//     /// Performs polynomial interpolation in over GF to reconstruct missing shards.
//     fn decode(d: *Decoder) ![][64]u8 {
//         const shards = &d.shards;

//         if (d.data_received_count + d.recovery_received_count < d.num_data_shards)
//             return error.NotEnoughShards;

//         const chunk_size = try std.math.ceilPowerOfTwo(u64, d.num_parity_shards);
//         const original_end = chunk_size + d.num_data_shards;

//         // mark missing recovery shards / erasures
//         for (0..d.num_parity_shards) |i| {
//             if (!d.received[i]) d.erasures[i] = 1;
//         }

//         @memset(d.erasures[d.num_parity_shards..chunk_size], 1);

//         // mark missing original shards
//         for (chunk_size..original_end) |i| {
//             if (!d.received[i]) d.erasures[i] = 1;
//         }

//         Engine.evalPoly(&d.erasures, original_end);

//         // apply erasure masks to all chunks
//         for (0..d.num_parity_shards) |i| {
//             const chunk = shards.data[i * shards.shard_length ..][0..shards.shard_length];
//             if (d.received[i]) Engine.mulScalar(chunk, d.erasures[i]) else @memset(chunk, @splat(0));
//         }
//         shards.zero(d.num_parity_shards, chunk_size);

//         // original region
//         for (chunk_size..original_end) |i| {
//             const chunk = shards.data[i * shards.shard_length ..][0..shards.shard_length];
//             if (d.received[i]) Engine.mulScalar(chunk, d.erasures[i]) else @memset(chunk, @splat(0));
//         }
//         shards.zero(original_end, shards.data.len);

//         // convert from freq to time domain
//         Engine.ifft(shards, 0, shards.data.len, original_end, 0);

//         // formal derivative (forney's algorithm)
//         for (1..shards.data.len) |i| {
//             // intCast is safe because i cannot be 0 nor usize max
//             const width: u64 = @as(u64, 1) << @intCast(@ctz(i));
//             const s0 = shards.data[(i - width) * shards.shard_length ..][0..width];
//             const s1 = shards.data[i * shards.shard_length ..][0..width];
//             util.xor(s0, s1);
//         }

//         // return to freq domain
//         Engine.fft(shards, 0, shards.data.len, original_end, 0);

//         // restore the missing (erased) shards
//         for (chunk_size..original_end) |i| if (!d.received[i]) {
//             Engine.mulScalar(
//                 shards.data[i * shards.shard_length ..][0..shards.shard_length],
//                 gf.modulus - d.erasures[i],
//             );
//         };

//         undoLastChunkEncoding(
//             d,
//             d.original_base_pos,
//             d.original_base_pos + d.num_data_shards,
//         );

//         return shards.data;
//     }
// };

fn undoLastChunkEncoding(e: anytype, start: usize, end: usize) void {
    const whole_chunk_count = e.shard_bytes / 64;
    const tail_len = e.shard_bytes % 64;

    if (tail_len == 0) return;

    for (start..end) |i| {
        var last_chunk = e.shards.data[i * e.shards.shard_length ..][0..e.shards.shard_length][whole_chunk_count];
        @memmove(last_chunk[tail_len / 2 ..], last_chunk[32..][0 .. tail_len / 2]);
    }
}

fn useHighRate(original: u64, recovery: u64) !bool {
    if (original > gf.order or recovery > gf.order) return error.UnsupportedShardCount;

    const original_pow2 = try std.math.ceilPowerOfTwo(u64, original);
    const recovery_pow2 = try std.math.ceilPowerOfTwo(u64, recovery);

    const smaller = @min(original_pow2, recovery_pow2);
    const larger = @max(original, recovery);

    if (original == 0 or recovery == 0 or smaller + larger > gf.order) {
        return error.UnsupportedShardCount;
    }

    return switch (std.math.order(original_pow2, recovery_pow2)) {
        .lt => false,
        .gt => true,
        .eq => original <= recovery,
    };
}

test {
    _ = Engine;
}
