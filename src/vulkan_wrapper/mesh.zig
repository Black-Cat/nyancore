const std = @import("std");

const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");
const nm = @import("../math/math.zig");

const Buffer = @import("buffer.zig").Buffer;
const CommandBuffer = @import("command_buffer.zig").CommandBuffer;
const Model = @import("../model/model.zig").Model;
const VmaAllocation = @import("vma_allocation.zig").VmaAllocation;

pub const Mesh = struct {
    vertex_buffer: Buffer,

    index_buffer: Buffer,
    index_type: vk.IndexType,
    index_count: usize,

    pub fn indexType2size(index_type: vk.IndexType) u64 {
        return switch (index_type) {
            .uint16 => 16,
            .uint32 => 32,
            else => 32,
        };
    }

    pub fn init(
        self: *Mesh,
        mapping_usage: VmaAllocation.MappingUsage,
        vertex_size: usize,
        vertex_count: usize,
        index_type: vk.IndexType,
        index_count: usize,
    ) void {
        self.index_type = index_type;
        self.vertex_buffer.init(vertex_size * vertex_count, .{ .vertex_buffer_bit = true }, mapping_usage);
        self.index_buffer.init(indexType2size(index_type) * index_count, .{ .index_buffer_bit = true }, mapping_usage);
        self.index_count = index_count;
    }

    pub fn initFromModel(self: *Mesh, model: *Model) void {
        var vertex_size: usize = 0;
        if (model.positions) |_| vertex_size += @sizeOf(nm.vec3);
        if (model.normals) |_| vertex_size += @sizeOf(nm.vec3);
        if (model.colors) |_| vertex_size += @sizeOf(nm.vec3);

        self.init(.sequential, vertex_size, model.positions.?.len, .uint32, model.indices.?.len);

        var index_mapped_buffer: []u8 = undefined;
        index_mapped_buffer.ptr = @ptrCast([*]u8, self.index_buffer.allocation.mapped_memory);
        index_mapped_buffer.len = model.indices.?.len * @sizeOf(u32);

        std.mem.copy(u8, index_mapped_buffer, std.mem.sliceAsBytes(model.indices.?));

        var mapped_buffer: []u8 = undefined;
        mapped_buffer.ptr = @ptrCast([*]u8, self.vertex_buffer.allocation.mapped_memory);
        mapped_buffer.len = model.positions.?.len * vertex_size;

        var offset: usize = 0;
        offset += copyBufferIfExist(model.positions, mapped_buffer, offset, vertex_size);
        offset += copyBufferIfExist(model.normals, mapped_buffer, offset, vertex_size);
        offset += copyBufferIfExist(model.colors, mapped_buffer, offset, vertex_size);

        self.index_buffer.flushWhole();
        self.vertex_buffer.flushWhole();
    }

    fn copyBufferIfExist(buffer: ?[]nm.vec3, dst: []u8, offset: usize, vertex_size: usize) usize {
        if (buffer == null) return 0;

        for (buffer.?) |e, ind| {
            const offset_index: usize = offset + ind * vertex_size;
            std.mem.bytesAsValue(nm.vec3, @ptrCast(*[16]u8, &dst[offset_index])).* = e;
        }

        return @sizeOf(nm.vec3);
    }

    pub fn bind(self: *const Mesh, command_buffer: *CommandBuffer) void {
        const offset: u64 = 0;
        vkfn.d.cmdBindVertexBuffers(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Buffer, &self.vertex_buffer.vk_ref), @ptrCast([*]const u64, &offset));
        vkfn.d.cmdBindIndexBuffer(command_buffer.vk_ref, self.index_buffer.vk_ref, 0, self.index_type);
    }

    pub fn destroy(self: *Mesh) void {
        self.vertex_buffer.destroy();
        self.index_buffer.destroy();
    }
};
