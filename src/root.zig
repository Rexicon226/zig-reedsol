const std = @import("std");
const builtin = @import("builtin");

const has_gfni = builtin.target.cpu.has(.x86, .gfni) and builtin.zig_backend == .stage2_llvm;
pub const Engine = switch (builtin.target.cpu.arch) {
    else => @import("engines/Generic.zig"),
};

pub fn encode(
    /// The input data shards. It's required by the caller to keep the memory
    /// alive during the encoding process, since we don't gain ownership of it.
    /// Shards have to be defined.
    data: []const []const u8,
    /// The output parity shards. Again, the caller owns the destination pointers,
    /// and is required to make sure they are valid while we write into them.
    /// Shards can be undefined.
    parity: []const []u8,
    /// Length of each shard. This applies to both data and parity.
    shard_bytes: usize,
) !void {
    if (!std.math.isPowerOfTwo(parity.len)) return error.ParityBufferSizeNotPowerOfTwo;
    if (!std.math.isPowerOfTwo(data.len)) return error.DataSizeNotPowerOfTwo;
    if (data.len == 0) return error.DataSizeIsZero;
    if (parity.len == 0) return error.ParitySizeIsZero;
    if (data.len < parity.len) return error.ParitySizeTooLarge;
    if (shard_bytes == 0 or shard_bytes & 1 != 0) return error.InvalidShardBytes;
    if (data[0].len != parity[0].len) return error.DataAndParityShardBytesDiffer;

    if (has_gfni and data.len == 32 and parity.len == 32) {
        return @import("engines/avx512.zig").encode(data, parity, shard_bytes);
    }

    return Engine.encode(data, parity, shard_bytes);
}
