const std = @import("std");
const builtin = @import("builtin");

const nm = @import("../math/math.zig");
const vk = @import("../vk.zig");

const jpg = @import("../image/jpg.zig");
const Image = @import("../image/image.zig").Image;

const MaterialInfo = @import("material_info.zig").MaterialInfo;
const Model = @import("model.zig").Model;
const Sampler = @import("../vulkan_wrapper/sampler.zig").Sampler;

const glb_signature: u32 = 0x46546C67;
const glb_version: u32 = 2;

pub fn check_header(reader: anytype) !bool {
    const valid_signature: bool = (try reader.readIntLittle(u32)) == glb_signature;
    const valid_version: bool = (try reader.readIntLittle(u32)) == glb_version;
    try reader.skipBytes(@sizeOf(u32), .{}); // Total length of the file in bytes
    return valid_signature and valid_version;
}

const json_chunk_type: u32 = 0x4E4F534A;
const bin_chunk_type: u32 = 0x004E4942;

fn getInt(comptime T: type, node: std.json.Value, comptime field_name: []const u8) T {
    return @intCast(T, node.Object.get(field_name).?.Integer);
}

fn getOptionalInt(comptime T: type, node: std.json.Value, comptime field_name: []const u8) ?T {
    const value = node.Object.get(field_name);
    if (value) |v| {
        return @intCast(T, v.Integer);
    } else {
        return null;
    }
}

fn getFloat(val: std.json.Value) f32 {
    return switch (val) {
        .Integer => @intToFloat(f32, val.Integer),
        .Float => @floatCast(f32, val.Float),
        else => @panic("Can't cast json value to float =c"),
    };
}

fn getVec3(array: *const std.json.Array) nm.vec3 {
    return .{
        getFloat(array.items[0]),
        getFloat(array.items[1]),
        getFloat(array.items[2]),
    };
}

const Buffer = struct {
    byte_length: usize,

    pub fn fromJson(json_node: std.json.Value) Buffer {
        return .{
            .byte_length = getInt(usize, json_node, "byteLength"),
        };
    }
};

const BufferView = struct {
    buffer: usize,
    byte_length: usize,
    byte_offset: usize,
    byte_stride: ?usize,
    target: ?u32,

    pub fn fromJson(json_node: std.json.Value) BufferView {
        return .{
            .buffer = getInt(usize, json_node, "buffer"),
            .byte_length = getInt(usize, json_node, "byteLength"),
            .byte_offset = getInt(usize, json_node, "byteOffset"),

            .target = getOptionalInt(u32, json_node, "target"),
            .byte_stride = getOptionalInt(usize, json_node, "byteStride"),
        };
    }
};

const GltfSampler = struct {
    sampler: Sampler,

    pub fn fromJson(json_node: std.json.Value) GltfSampler {
        const mag_filter: usize = getInt(usize, json_node, "magFilter");
        const min_filter: usize = getInt(usize, json_node, "minFilter");
        const wrap_s: ?usize = getOptionalInt(usize, json_node, "wrapS");
        const wrap_t: ?usize = getOptionalInt(usize, json_node, "wrapT");

        var sampler: GltfSampler = undefined;
        sampler.sampler.sampler_info = Sampler.default_sampler_info;

        sampler.sampler.sampler_info.mag_filter = switch (mag_filter) {
            0x2600 => .nearest,
            0x2601 => .linear,
            else => @panic("Unknown mag filter"),
        };

        sampler.sampler.sampler_info.min_filter = switch (min_filter) {
            0x2600, 0x2700, 0x2702 => .nearest,
            0x2601, 0x2701, 0x2703 => .linear,
            else => @panic("Unknown min filter"),
        };

        sampler.sampler.sampler_info.mipmap_mode = switch (min_filter) {
            0x2600, 0x2601, 0x2700, 0x2701 => .nearest,
            0x2702, 0x2703 => .linear,
            else => @panic("Unknown min filter"),
        };

        if (wrap_s) |w|
            sampler.sampler.sampler_info.address_mode_u = addressModeFromOpenGL(w);
        if (wrap_t) |w|
            sampler.sampler.sampler_info.address_mode_v = addressModeFromOpenGL(w);

        return sampler;
    }

    fn addressModeFromOpenGL(val: usize) vk.SamplerAddressMode {
        return switch (val) {
            0x2901 => .repeat,
            0x8370 => .mirrored_repeat,
            0x812F => .clamp_to_edge,
            0x2900 => .clamp_to_border,
            else => @panic("Unknown address mode"),
        };
    }
};

const GltfImage = struct {
    buffer_view: usize,
    mime_type: []const u8,
    image: Image,

    pub fn fromJson(json_node: std.json.Value) GltfImage {
        var image: GltfImage = undefined;
        image.buffer_view = getInt(usize, json_node, "bufferView");
        image.mime_type = json_node.Object.get("mimeType").?.String;
        return image;
    }
};

const GltfTexture = struct {
    source_ind: usize,
    sampler_ind: usize,

    source: *GltfImage,
    sampler: *GltfSampler,

    pub fn fromJson(json_node: std.json.Value) GltfTexture {
        var tex: GltfTexture = undefined;
        tex.source_ind = getInt(usize, json_node, "source");
        tex.sampler_ind = getInt(usize, json_node, "sampler");
        return tex;
    }

    pub fn link(self: *GltfTexture, images: []GltfImage, samplers: []GltfSampler) void {
        self.source = &images[self.source_ind];
        self.sampler = &samplers[self.sampler_ind];
    }
};

const GltfMaterial = struct {
    name: []const u8,
    double_sided: bool,
    pbr_metallic_factor: f64,

    normal_texture_index: usize,
    pbr_base_color_index: usize,
    pbr_metallic_roughness_index: usize,

    normal_texture: *GltfTexture,
    pbr_base_color: *GltfTexture,
    pbr_metallic_roughness: *GltfTexture,

    pub fn fromJson(json_node: std.json.Value) GltfMaterial {
        var mat: GltfMaterial = undefined;

        mat.name = json_node.Object.get("name").?.String;
        mat.double_sided = json_node.Object.get("doubleSided").?.Bool;
        mat.normal_texture_index = @intCast(usize, json_node.Object.get("normalTexture").?.Object.get("index").?.Integer);

        var pbr_node = json_node.Object.get("pbrMetallicRoughness").?.Object;
        mat.pbr_base_color_index = @intCast(usize, pbr_node.get("baseColorTexture").?.Object.get("index").?.Integer);
        mat.pbr_metallic_roughness_index = @intCast(usize, pbr_node.get("metallicRoughnessTexture").?.Object.get("index").?.Integer);

        mat.pbr_metallic_factor = getFloat(pbr_node.get("metallicFactor").?);

        return mat;
    }

    pub fn link(self: *GltfMaterial, textures: []GltfTexture) void {
        self.normal_texture = &textures[self.normal_texture_index];
        self.pbr_base_color = &textures[self.pbr_base_color_index];
        self.pbr_metallic_roughness = &textures[self.pbr_metallic_roughness_index];
    }

    pub fn toMaterialInfo(self: *GltfMaterial, allocator: std.mem.Allocator) MaterialInfo {
        const textures = [_]*GltfTexture{ self.pbr_base_color, self.pbr_metallic_roughness, self.normal_texture };
        const images: []Image = allocator.alloc(Image, textures.len) catch unreachable;
        const samplers: []Sampler = allocator.alloc(Sampler, textures.len) catch unreachable;

        for (textures) |tex, ind| {
            images[ind] = tex.source.image.clone(allocator);
            samplers[ind] = undefined;
            samplers[ind].sampler_info = tex.sampler.sampler.sampler_info;
        }

        return .{
            .allocator = allocator,
            .name = allocator.dupe(u8, self.name) catch unreachable,
            .double_sided = self.double_sided,
            .images = images,
            .samplers = samplers,
        };
    }
};

const Accessor = struct {
    const AccessorType = enum {
        scalar,
        vec2,
        vec3,
        vec4,
        mat2,
        mat3,
        mat4,

        pub fn fromString(str: []const u8) AccessorType {
            if (std.mem.eql(u8, "VEC2", str)) return .vec2;
            if (std.mem.eql(u8, "VEC3", str)) return .vec3;
            if (std.mem.eql(u8, "VEC4", str)) return .vec4;
            if (std.mem.eql(u8, "MAT2", str)) return .mat2;
            if (std.mem.eql(u8, "MAT3", str)) return .mat3;
            if (std.mem.eql(u8, "MAT4", str)) return .mat4;
            return .scalar;
        }

        pub fn numberOfElements(self: AccessorType) usize {
            return switch (self) {
                .scalar => 1,
                .vec2 => 2,
                .vec3 => 3,
                .vec4 => 4,
                .mat2 => 4,
                .mat3 => 9,
                .mat4 => 16,
            };
        }
    };

    const ComponentType = enum {
        i8,
        u8,
        i16,
        u16,
        u32,
        f32,

        pub fn fromInt(i: u32) ComponentType {
            return switch (i) {
                5120 => .i8,
                5121 => .u8,
                5122 => .i16,
                5123 => .u16,
                5125 => .u32,
                5126 => .f32,
                else => blk: {
                    std.debug.assert(false); // unknown component type in accessor
                    break :blk .i8;
                },
            };
        }

        pub fn getByteSize(self: ComponentType) usize {
            return switch (self) {
                .i8, .u8 => 1,
                .i16, .u16 => 2,
                .u32, .f32 => 4,
            };
        }

        pub fn readU32(self: ComponentType, buffer: *u8) u32 {
            return switch (self) {
                .i8 => @intCast(u32, @ptrCast(*i8, buffer).*),
                .u8 => @intCast(u32, @ptrCast(*u8, buffer).*),
                .i16 => @intCast(u32, @ptrCast(*i16, @alignCast(@alignOf(i16), buffer)).*),
                .u16 => @intCast(u32, @ptrCast(*u16, @alignCast(@alignOf(u16), buffer)).*),
                .u32 => @ptrCast(*u32, @alignCast(@alignOf(u32), buffer)).*,
                .f32 => @floatToInt(u32, @ptrCast(*f32, @alignCast(@alignOf(f32), buffer)).*),
            };
        }

        pub fn readF32(self: ComponentType, buffer: *u8) f32 {
            return switch (self) {
                .i8 => @intToFloat(f32, @ptrCast(*i8, buffer).*),
                .u8 => @intToFloat(f32, @ptrCast(*u8, buffer).*),
                .i16 => @intToFloat(f32, @ptrCast(*i16, @alignCast(@alignOf(i16), buffer)).*),
                .u16 => @intToFloat(f32, @ptrCast(*u16, @alignCast(@alignOf(u16), buffer)).*),
                .u32 => @intToFloat(f32, @ptrCast(*u32, @alignCast(@alignOf(u32), buffer)).*),
                .f32 => @ptrCast(*f32, @alignCast(@alignOf(f32), buffer)).*,
            };
        }
    };

    buffer_view: usize,
    byte_offset: usize,
    component_type: ComponentType,
    count: u32,
    accessor_type: AccessorType,

    buffer_view_ptr: *BufferView = undefined,

    pub fn fromJson(json_node: std.json.Value) Accessor {
        return .{
            .buffer_view = getInt(usize, json_node, "bufferView"),
            .count = getInt(u32, json_node, "count"),

            .byte_offset = getOptionalInt(usize, json_node, "byteOffset") orelse 0,

            .component_type = ComponentType.fromInt(getInt(u32, json_node, "componentType")),
            .accessor_type = AccessorType.fromString(json_node.Object.get("type").?.String),
        };
    }
};

fn parseArray(comptime ElementType: type, comptime name: []const u8, root: std.json.Value, allocator: std.mem.Allocator) []ElementType {
    var gltf_array = root.Object.get(name).?.Array;
    var array: []ElementType = allocator.alloc(ElementType, gltf_array.items.len) catch unreachable;
    for (array) |*el, ind|
        el.* = ElementType.fromJson(gltf_array.items[ind]);
    return array;
}

pub fn parse(reader: anytype, allocator: std.mem.Allocator) ![]Model {
    const json_chunk_length: u32 = try reader.readIntLittle(u32);

    const json_valid_signature: bool = (try reader.readIntLittle(u32)) == json_chunk_type;
    if (!json_valid_signature)
        return error.InvalidJsonSignature;

    var buffer: []u8 = try readData(reader, allocator, json_chunk_length);
    defer allocator.free(buffer);

    var parser = std.json.Parser.init(allocator, false);
    defer parser.deinit();

    var json_tree = try parser.parse(buffer);
    defer json_tree.deinit();

    var buffers: []Buffer = parseArray(Buffer, "buffers", json_tree.root, allocator);
    defer allocator.free(buffers);

    var buffer_views: []BufferView = parseArray(BufferView, "bufferViews", json_tree.root, allocator);
    defer allocator.free(buffer_views);

    var accessors: []Accessor = parseArray(Accessor, "accessors", json_tree.root, allocator);
    defer allocator.free(accessors);

    for (accessors) |*a|
        a.buffer_view_ptr = &buffer_views[a.buffer_view];

    var samplers: []GltfSampler = parseArray(GltfSampler, "samplers", json_tree.root, allocator);
    defer allocator.free(samplers);

    var images: []GltfImage = parseArray(GltfImage, "images", json_tree.root, allocator);
    defer allocator.free(images);

    var textures: []GltfTexture = parseArray(GltfTexture, "textures", json_tree.root, allocator);
    defer allocator.free(textures);

    for (textures) |*tex|
        tex.link(images, samplers);

    var materials: []GltfMaterial = parseArray(GltfMaterial, "materials", json_tree.root, allocator);
    defer allocator.free(materials);

    for (materials) |*mat|
        mat.link(textures);

    const bin_chunk_size: u32 = try reader.readIntLittle(u32);
    const valid_bin_signature: bool = (try reader.readIntLittle(u32)) == bin_chunk_type;
    if (!valid_bin_signature)
        return error.InvalidBinSignature;

    var bin_buffer: []u8 = try readData(reader, allocator, bin_chunk_size);

    for (images) |*im| {
        const buffer_view: *BufferView = &buffer_views[im.buffer_view];
        var image_data: []u8 = extractImageBuffer(bin_buffer, buffer_view);

        var stream = std.io.fixedBufferStream(image_data);
        const stream_reader = stream.reader();

        _ = jpg.checkHeader(stream_reader) catch unreachable;
        im.image = jpg.parse(stream_reader, allocator) catch unreachable;
    }

    var meshes = json_tree.root.Object.get("meshes").?.Array;
    var models: []Model = allocator.alloc(Model, meshes.items.len) catch unreachable;
    var nodes = json_tree.root.Object.get("nodes").?.Array;

    for (nodes.items) |n, ind| {
        var mesh_ind: usize = getInt(usize, n, "mesh");
        var mesh = meshes.items[mesh_ind];

        var primitives = mesh.Object.get("primitives").?.Array.items[0].Object;

        var model: Model = .{ .allocator = allocator };
        model.transform = nm.Mat4x4.identity();
        model.name = allocator.dupe(u8, n.Object.get("name").?.String) catch unreachable;

        if (n.Object.get("translation")) |tr| {
            const vec: nm.vec3 = getVec3(&tr.Array);
            model.transform = nm.Mat4x4.translate(model.transform, vec);
        }

        const indices: usize = @intCast(usize, primitives.get("indices").?.Integer);
        model.indices = extractBuffer(u32, bin_buffer, &accessors[indices], allocator);

        const mat_index: usize = @intCast(usize, primitives.get("material").?.Integer);
        const mat: *GltfMaterial = &materials[mat_index];
        model.mat = mat.toMaterialInfo(model.allocator);

        primitives = primitives.get("attributes").?.Object;
        if (primitives.get("POSITION")) |val|
            model.positions = extractBuffer(nm.vec3, bin_buffer, &accessors[@intCast(usize, val.Integer)], allocator);
        if (primitives.get("NORMAL")) |val|
            model.normals = extractBuffer(nm.vec3, bin_buffer, &accessors[@intCast(usize, val.Integer)], allocator);
        if (primitives.get("COLOR_0")) |val|
            model.colors = extractBuffer(nm.vec3, bin_buffer, &accessors[@intCast(usize, val.Integer)], allocator);

        models[ind] = model;
    }

    return models;
}

fn extractBuffer(comptime ElementType: type, buffer: []u8, accessor: *Accessor, allocator: std.mem.Allocator) []ElementType {
    const component_size: usize = accessor.component_type.getByteSize();

    var result: []ElementType = allocator.alloc(ElementType, accessor.count) catch unreachable;

    const byte_stride: usize = accessor.buffer_view_ptr.byte_stride orelse component_size * accessor.accessor_type.numberOfElements();

    var byte_offset: usize = accessor.byte_offset + accessor.buffer_view_ptr.byte_offset;
    for (result) |*elem| {
        if (ElementType == u32)
            elem.* = accessor.component_type.readU32(&buffer[byte_offset]);
        if (ElementType == nm.vec3)
            elem.* = .{
                accessor.component_type.readF32(&buffer[byte_offset]),
                accessor.component_type.readF32(&buffer[byte_offset + component_size]),
                accessor.component_type.readF32(&buffer[byte_offset + 2 * component_size]),
            };

        byte_offset += byte_stride;
    }

    return result;
}

fn extractImageBuffer(buffer: []u8, buffer_view: *BufferView) []u8 {
    return buffer[buffer_view.byte_offset .. buffer_view.byte_offset + buffer_view.byte_length];
}

fn readData(reader: anytype, allocator: std.mem.Allocator, chunk_length: u32) ![]u8 {
    var buffer: []u8 = allocator.alloc(u8, chunk_length) catch unreachable;
    _ = try reader.readNoEof(buffer);

    if (builtin.target.cpu.arch.endian() != .Little) {
        for (std.mem.bytesAsSlice(u32, buffer)) |*v|
            v.* = @byteSwap(u32, v.*);
    }

    return buffer;
}
