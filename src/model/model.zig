const std = @import("std");

const nm = @import("../math/math.zig");
const vk = @import("../vk.zig");

const AssetMap = @import("../application/asset.zig").AssetMap;

pub const Model = struct {
    allocator: std.mem.Allocator,

    name: []const u8 = "NO MODEL NAME",
    transform: nm.mat4x4 = nm.Mat4x4.identity(),

    indices: ?[]u32 = null,

    positions: ?[]nm.vec3 = null,
    normals: ?[]nm.vec3 = null,
    colors: ?[]nm.vec3 = null,

    pub fn generateInputBindings(self: *Model) vk.VertexInputBindingDescription {
        var vertex_size: usize = 0;
        if (self.positions != null) vertex_size += @sizeOf(nm.vec3);
        if (self.normals != null) vertex_size += @sizeOf(nm.vec3);
        if (self.colors != null) vertex_size += @sizeOf(nm.vec3);

        return .{
            .binding = 0,
            .stride = @intCast(u32, vertex_size),
            .input_rate = .vertex,
        };
    }

    pub fn generateAttributeDescriptions(self: *Model, allocator: std.mem.Allocator) []vk.VertexInputAttributeDescription {
        var attributes = std.ArrayList(vk.VertexInputAttributeDescription).init(allocator);

        if (self.positions != null)
            attributes.append(.{
                .binding = 0,
                .location = @intCast(u32, attributes.items.len),
                .format = .r32g32b32_sfloat,
                .offset = @intCast(u32, attributes.items.len * @sizeOf(nm.vec3)),
            }) catch unreachable;
        if (self.normals != null)
            attributes.append(.{
                .binding = 0,
                .location = @intCast(u32, attributes.items.len),
                .format = .r32g32b32_sfloat,
                .offset = @intCast(u32, attributes.items.len * @sizeOf(nm.vec3)),
            }) catch unreachable;
        if (self.colors != null)
            attributes.append(.{
                .binding = 0,
                .location = @intCast(u32, attributes.items.len),
                .format = .r32g32b32_sfloat,
                .offset = @intCast(u32, attributes.items.len * @sizeOf(nm.vec3)),
            }) catch unreachable;

        return attributes.toOwnedSlice();
    }

    pub fn generateAssetMap(self: *Model, allocator: std.mem.Allocator) AssetMap {
        var map: AssetMap = AssetMap.init(allocator);

        map.put("name", allocator.dupe(u8, self.name) catch unreachable) catch unreachable;
        map.put("transform", std.mem.sliceAsBytes(@ptrCast(*[16]f32, &self.transform)[0..])) catch unreachable;

        if (self.indices) |buf|
            map.put("indices", std.mem.sliceAsBytes(buf)) catch unreachable;

        if (self.positions) |buf|
            map.put("positions", std.mem.sliceAsBytes(buf)) catch unreachable;

        if (self.normals) |buf|
            map.put("normals", std.mem.sliceAsBytes(buf)) catch unreachable;

        if (self.colors) |buf|
            map.put("colors", std.mem.sliceAsBytes(buf)) catch unreachable;

        return map;
    }

    pub fn deinitAssetMap(map: *AssetMap) void {
        map.allocator.free(map.get("name") orelse unreachable);
        map.deinit();
    }

    pub fn createFromAssetMap(map: *AssetMap, allocator: std.mem.Allocator) Model {
        var model: Model = .{ .allocator = allocator };

        model.name = allocator.dupe(u8, map.get("name") orelse unreachable) catch unreachable;
        var transform = map.get("transform") orelse unreachable;
        model.transform = @ptrCast(*nm.mat4x4, @alignCast(@alignOf(nm.mat4x4), transform)).*;

        if (map.contains("indices"))
            model.indices = std.mem.bytesAsSlice(u32, @alignCast(@alignOf(u32), map.get("indices") orelse unreachable));

        if (map.contains("positions"))
            model.positions = std.mem.bytesAsSlice(nm.vec3, @alignCast(@alignOf(nm.vec3), map.get("positions") orelse unreachable));
        if (map.contains("normals"))
            model.normals = std.mem.bytesAsSlice(nm.vec3, @alignCast(@alignOf(nm.vec3), map.get("normals") orelse unreachable));
        if (map.contains("colors"))
            model.colors = std.mem.bytesAsSlice(nm.vec3, @alignCast(@alignOf(nm.vec3), map.get("colors") orelse unreachable));

        return model;
    }
};
