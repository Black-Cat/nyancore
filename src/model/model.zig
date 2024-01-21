const std = @import("std");

const nm = @import("../math/math.zig");
const vk = @import("../vk.zig");

const AssetMap = @import("../application/asset.zig").AssetMap;

const MaterialInfo = @import("material_info.zig").MaterialInfo;

const Image = @import("../image/image.zig").Image;
const Sampler = @import("../vulkan_wrapper/sampler.zig").Sampler;

pub const Model = struct {
    allocator: std.mem.Allocator,

    name: []const u8 = "NO MODEL NAME",
    transform: nm.mat4x4 = nm.Mat4x4.identity(),

    indices: ?[]u32 = null,

    positions: ?[]nm.vec3 = null,
    normals: ?[]nm.vec3 = null,
    colors: ?[]nm.vec3 = null,

    mat: MaterialInfo = undefined,

    pub fn generateInputBindings(self: *Model) vk.VertexInputBindingDescription {
        var vertex_size: usize = 0;
        if (self.positions != null) vertex_size += @sizeOf(nm.vec3);
        if (self.normals != null) vertex_size += @sizeOf(nm.vec3);
        if (self.colors != null) vertex_size += @sizeOf(nm.vec3);

        return .{
            .binding = 0,
            .stride = @intCast(vertex_size),
            .input_rate = .vertex,
        };
    }

    pub fn generateAttributeDescriptions(self: *Model, allocator: std.mem.Allocator) []vk.VertexInputAttributeDescription {
        var attributes = std.ArrayList(vk.VertexInputAttributeDescription).init(allocator);

        if (self.positions != null)
            attributes.append(.{
                .binding = 0,
                .location = @intCast(attributes.items.len),
                .format = .r32g32b32_sfloat,
                .offset = @intCast(attributes.items.len * @sizeOf(nm.vec3)),
            }) catch unreachable;
        if (self.normals != null)
            attributes.append(.{
                .binding = 0,
                .location = @intCast(attributes.items.len),
                .format = .r32g32b32_sfloat,
                .offset = @intCast(attributes.items.len * @sizeOf(nm.vec3)),
            }) catch unreachable;
        if (self.colors != null)
            attributes.append(.{
                .binding = 0,
                .location = @intCast(attributes.items.len),
                .format = .r32g32b32_sfloat,
                .offset = @intCast(attributes.items.len * @sizeOf(nm.vec3)),
            }) catch unreachable;

        return attributes.toOwnedSlice();
    }

    pub fn generateAssetMap(self: *Model, allocator: std.mem.Allocator) AssetMap {
        var map: AssetMap = AssetMap.init(allocator);

        map.put("name", allocator.dupe(u8, self.name) catch unreachable) catch unreachable;
        map.put("transform", std.mem.sliceAsBytes(@as(*[16]f32, @ptrCast(&self.transform))[0..])) catch unreachable;

        if (self.indices) |buf|
            map.put("indices", std.mem.sliceAsBytes(buf)) catch unreachable;

        if (self.positions) |buf|
            map.put("positions", std.mem.sliceAsBytes(buf)) catch unreachable;

        if (self.normals) |buf|
            map.put("normals", std.mem.sliceAsBytes(buf)) catch unreachable;

        if (self.colors) |buf|
            map.put("colors", std.mem.sliceAsBytes(buf)) catch unreachable;

        map.put("mat_name", allocator.dupe(u8, self.mat.name) catch unreachable) catch unreachable;
        var double_sided: u8 = @intCast(@intFromBool(self.mat.double_sided));
        map.put("mat_double_sided", std.mem.asBytes(&double_sided)) catch unreachable;
        map.put("mat_tex_count", std.mem.asBytes(&self.mat.images.len)) catch unreachable;

        var sampler_infos = allocator.alloc(vk.SamplerCreateInfo, self.mat.samplers.len) catch unreachable;
        for (self.mat.samplers, &sampler_infos) |sampler, *si|
            si.* = sampler.sampler_info;
        map.put("mat_samplers", std.mem.sliceAsBytes(sampler_infos)) catch unreachable;

        var image_data_size: usize = 0;
        var image_sizes: []usize = allocator.alloc(usize, self.mat.images.len * 2) catch unreachable;

        for (self.mat.images, 0..) |image, ind| {
            image_data_size += image.data.len;

            image_sizes[2 * ind] = image.width;
            image_sizes[2 * ind + 1] = image.height;
        }

        map.put("mat_image_sizes", std.mem.sliceAsBytes(image_sizes)) catch unreachable;

        var image_data: []u8 = allocator.alloc(u8, image_data_size) catch unreachable;

        var image_data_offset: usize = 0;
        for (self.mat.images) |image| {
            std.mem.copy(u8, image_data[image_data_offset..], image.data);
            image_data_offset += image.data.len;
        }
        map.put("mat_image_data", image_data) catch unreachable;

        return map;
    }

    pub fn deinitAssetMap(map: *AssetMap) void {
        map.allocator.free(map.get("name") orelse unreachable);
        map.allocator.free(map.get("mat_name") orelse unreachable);
        map.allocator.free(map.get("mat_image_sizes") orelse unreachable);
        map.allocator.free(map.get("mat_image_data") orelse unreachable);
        map.allocator.free(map.get("mat_samplers") orelse unreachable);
        map.deinit();
    }

    pub fn createFromAssetMap(map: *AssetMap, allocator: std.mem.Allocator) Model {
        var model: Model = .{ .allocator = allocator };

        model.name = allocator.dupe(u8, map.get("name") orelse unreachable) catch unreachable;
        var transform = map.get("transform") orelse unreachable;
        model.transform = @as(*nm.mat4x4, @ptrCast(@alignCast(transform))).*;

        if (map.contains("indices"))
            model.indices = std.mem.bytesAsSlice(u32, @alignCast(map.get("indices") orelse unreachable));

        if (map.contains("positions"))
            model.positions = std.mem.bytesAsSlice(nm.vec3, @alignCast(map.get("positions") orelse unreachable));
        if (map.contains("normals"))
            model.normals = std.mem.bytesAsSlice(nm.vec3, @alignCast(map.get("normals") orelse unreachable));
        if (map.contains("colors"))
            model.colors = std.mem.bytesAsSlice(nm.vec3, @alignCast(map.get("colors") orelse unreachable));

        model.mat.allocator = allocator;
        model.mat.name = allocator.dupe(u8, map.get("mat_name") orelse unreachable) catch unreachable;
        model.mat.double_sided = (map.get("mat_double_sided") orelse unreachable)[0] == 1;

        var map_tex_count: []u8 = map.get("mat_tex_count") orelse unreachable;
        var tex_count: usize = @as(*usize, @alignCast(std.mem.bytesAsValue(usize, map_tex_count[0..8]))).*;
        model.mat.samplers = allocator.alloc(Sampler, tex_count) catch unreachable;
        model.mat.images = allocator.alloc(Image, tex_count) catch unreachable;

        var sampler_infos = std.mem.bytesAsSlice(vk.SamplerCreateInfo, map.get("mat_samplers") orelse unreachable);
        for (sampler_infos, &model.mat.samplers) |si, *s|
            s.sampler_info = si;

        var image_sizes = std.mem.bytesAsSlice(usize, map.get("mat_image_sizes") orelse unreachable);
        for (image_sizes, 0..) |is, ind| {
            var image: *Image = &model.mat.images[ind / 2];
            var size: *usize = if (ind % 2 == 0) &image.width else &image.height;
            size.* = is;
        }

        for (model.mat.images) |*im|
            im.data = allocator.alloc(u8, 4 * im.width * im.height) catch unreachable;

        var image_data: []u8 = map.get("mat_image_data") orelse unreachable;
        var image_data_offset: usize = 0;
        for (model.mat.images) |im|
            std.mem.copy(u8, im.data, image_data[image_data_offset .. image_data_offset + im.data.len]);

        return model;
    }
};
