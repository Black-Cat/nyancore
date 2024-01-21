const std = @import("std");

const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");
const nm = @import("../math/math.zig");

const Buffer = @import("buffer.zig").Buffer;
const CommandBuffer = @import("command_buffer.zig").CommandBuffer;
const Model = @import("../model/model.zig").Model;
const VmaAllocation = @import("vma_allocation.zig").VmaAllocation;
const TransferContext = @import("transfer_context.zig").TransferContext;

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
        self.vertex_buffer.init(vertex_size * vertex_count, .{ .vertex_buffer_bit = true, .transfer_dst_bit = true }, mapping_usage);
        self.index_buffer.init(indexType2size(index_type) * index_count, .{ .index_buffer_bit = true, .transfer_dst_bit = true }, mapping_usage);
        self.index_count = index_count;
    }

    pub fn initFromModel(self: *Mesh, model: *Model) void {
        var vertex_size: usize = 0;
        if (model.positions) |_| vertex_size += @sizeOf(nm.vec3);
        if (model.normals) |_| vertex_size += @sizeOf(nm.vec3);
        if (model.colors) |_| vertex_size += @sizeOf(nm.vec3);

        self.init(.no_mapping, vertex_size, model.positions.?.len, .uint32, model.indices.?.len);

        TransferContext.transfer_buffer(&self.index_buffer, std.mem.sliceAsBytes(model.indices.?));

        var temp_buffer: []u8 = vkctxt.allocator.alloc(u8, model.positions.?.len * vertex_size) catch unreachable;
        defer vkctxt.allocator.free(temp_buffer);

        var offset: usize = 0;
        offset += copyBufferIfExist(model.positions, temp_buffer, offset, vertex_size);
        offset += copyBufferIfExist(model.normals, temp_buffer, offset, vertex_size);
        offset += copyBufferIfExist(model.colors, temp_buffer, offset, vertex_size);

        TransferContext.transfer_buffer(&self.vertex_buffer, temp_buffer);
    }

    fn copyBufferIfExist(buffer: ?[]nm.vec3, dst: []u8, offset: usize, vertex_size: usize) usize {
        if (buffer == null) return 0;

        for (buffer.?, 0..) |e, ind| {
            const offset_index: usize = offset + ind * vertex_size;
            std.mem.bytesAsValue(nm.vec3, @as(*[16]u8, @ptrCast(&dst[offset_index]))).* = e;
        }

        return @sizeOf(nm.vec3);
    }

    pub fn bind(self: *const Mesh, command_buffer: *CommandBuffer) void {
        const offset: u64 = 0;
        vkfn.d.cmdBindVertexBuffers(command_buffer.vk_ref, 0, 1, @ptrCast(&self.vertex_buffer.vk_ref), @ptrCast(&offset));
        vkfn.d.cmdBindIndexBuffer(command_buffer.vk_ref, self.index_buffer.vk_ref, 0, self.index_type);
    }

    pub fn destroy(self: *Mesh) void {
        self.vertex_buffer.destroy();
        self.index_buffer.destroy();
    }
};
