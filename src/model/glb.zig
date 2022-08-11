const std = @import("std");

const nm = @import("../math/math.zig");

const Model = @import("model.zig").Model;

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

pub fn parse(reader: anytype, allocator: std.mem.Allocator) !Model {
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

    var meshes = json_tree.root.Object.get("meshes").?.Array;
    var main_mesh = meshes.items[0];

    var buffers: []Buffer = parseArray(Buffer, "buffers", json_tree.root, allocator);
    defer allocator.free(buffers);

    var buffer_views: []BufferView = parseArray(BufferView, "bufferViews", json_tree.root, allocator);
    defer allocator.free(buffer_views);

    var accessors: []Accessor = parseArray(Accessor, "accessors", json_tree.root, allocator);
    defer allocator.free(accessors);

    for (accessors) |*a|
        a.buffer_view_ptr = &buffer_views[a.buffer_view];

    const bin_chunk_size: u32 = try reader.readIntLittle(u32);
    const valid_bin_signature: bool = (try reader.readIntLittle(u32)) == bin_chunk_type;
    if (!valid_bin_signature)
        return error.InvalidBinSignature;

    var bin_buffer: []u8 = try readData(reader, allocator, bin_chunk_size);

    var primitives = main_mesh.Object.get("primitives").?.Array.items[0].Object;

    var model: Model = .{ .allocator = allocator };
    model.name = allocator.dupe(u8, main_mesh.Object.get("name").?.String) catch unreachable;

    const indices: usize = @intCast(usize, primitives.get("indices").?.Integer);
    model.indices = extractBuffer(u32, bin_buffer, &accessors[indices], allocator);

    primitives = primitives.get("attributes").?.Object;
    if (primitives.get("POSITION")) |val|
        model.positions = extractBuffer(nm.vec3, bin_buffer, &accessors[@intCast(usize, val.Integer)], allocator);
    if (primitives.get("NORMAL")) |val|
        model.normals = extractBuffer(nm.vec3, bin_buffer, &accessors[@intCast(usize, val.Integer)], allocator);
    if (primitives.get("COLOR_0")) |val|
        model.colors = extractBuffer(nm.vec3, bin_buffer, &accessors[@intCast(usize, val.Integer)], allocator);

    return model;
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

fn readData(reader: anytype, allocator: std.mem.Allocator, chunk_length: u32) ![]u8 {
    var buffer: []u8 = allocator.alloc(u8, chunk_length) catch unreachable;
    for (std.mem.bytesAsSlice(u32, buffer)) |*v|
        v.* = try reader.readIntLittle(u32);
    return buffer;
}
