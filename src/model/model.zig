const std = @import("std");

const nm = @import("../math/math.zig");
const vk = @import("../vk.zig");

pub const Model = struct {
    allocator: std.mem.Allocator,

    name: []const u8 = "NO MODEL NAME",

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
};
