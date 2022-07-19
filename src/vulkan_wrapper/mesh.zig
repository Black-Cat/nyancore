const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const Buffer = @import("buffer.zig").Buffer;
const CommandBuffer = @import("command_buffer.zig").CommandBuffer;

pub const Mesh = struct {
    vertex_buffer: Buffer,
    index_buffer: Buffer,

    pub fn indexType2size(index_type: vk.IndexType) u64 {
        return switch (index_type) {
            .uint16 => 16,
            .uint32 => 32,
            else => 32,
        };
    }

    pub fn init(
        self: *Mesh,
        mapping_usage: Buffer.MappingUsage,
        vertex_size: usize,
        vertex_count: usize,
        index_type: vk.IndexType,
        index_count: usize,
    ) void {
        self.vertex_buffer.init(vertex_size * vertex_count, .{ .vertex_buffer_bit = true }, mapping_usage);
        self.index_buffer.init(indexType2size(index_type) * index_count, .{ .index_buffer_bit = true }, mapping_usage);
    }

    pub fn bind(self: *Mesh, command_buffer: *CommandBuffer) void {
        const offset: u64 = 0;
        vkfn.d.cmdBindVertexBuffers(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Buffer, &self.vertex_buffer.vk_ref), @ptrCast([*]const u64, &offset));
        vkfn.d.cmdBindIndexBuffer(command_buffer.vk_ref, self.index_buffer.vk_ref, 0, .uint16);
    }

    pub fn destroy(self: *Mesh) void {
        self.vertex_buffer.destroy();
        self.index_buffer.destroy();
    }
};
