const std = @import("std");

pub const AssetMap = std.StringHashMap([]u8);

pub fn serializeAsset(writer: anytype, comptime asset_type: []const u8, data: AssetMap) !void {
    try writer.writeIntLittle(u32, @intCast(u32, asset_type.len));
    try writer.writeAll(asset_type);

    try writer.writeIntLittle(u32, @intCast(u32, data.count()));

    var it = data.iterator();
    while (it.next()) |kv| {
        try writer.writeIntLittle(u32, @intCast(u32, kv.key_ptr.*.len));
        try writer.writeAll(kv.key_ptr.*);

        try writer.writeIntLittle(u32, @intCast(u32, kv.value_ptr.*.len));
        try writer.writeAll(kv.value_ptr.*);
    }
}

pub fn deserializeAsset(reader: anytype, allocator: std.mem.Allocator) !AssetMap {
    // Parse asset type, not used right now
    var temp: u32 = try reader.readIntLittle(u32);
    try reader.skipBytes(temp, .{});

    var map: AssetMap = AssetMap.init(allocator);

    temp = try reader.readIntLittle(u32);
    try map.ensureTotalCapacity(temp);

    while (temp > 0) : (temp -= 1) {
        var buf_size: u32 = try reader.readIntLittle(u32);
        var key: []u8 = try allocator.alloc(u8, buf_size);
        _ = try reader.readAll(key);

        buf_size = try reader.readIntLittle(u32);
        var value: []u8 = try allocator.alloc(u8, buf_size);
        _ = try reader.readAll(value);

        map.putAssumeCapacityNoClobber(key, value);
    }

    return map;
}
