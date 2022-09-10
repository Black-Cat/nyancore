const vk = @import("../../../vk.zig");
const rg = @import("../render_graph.zig");

const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../../../vulkan_wrapper/vulkan_functions.zig");

const Buffer = @import("../../../vulkan_wrapper/buffer.zig").Buffer;

pub fn StorageBuffer(comptime BufferType: type) type {
    return struct {
        const SelfType = StorageBuffer(BufferType);

        buffers: []Buffer,
        data: [][]BufferType,
        buffer_size: usize,

        pub fn init(self: *SelfType, object_count: usize) void {
            const min_alignment: usize = @intCast(usize, vkctxt.physical_device.device_properties.limits.min_storage_buffer_offset_alignment);

            const in_flight: usize = @intCast(usize, rg.global_render_graph.in_flight);
            self.buffer_size = (@sizeOf(BufferType) * object_count + min_alignment - 1) & ~(min_alignment - 1);

            self.buffers = vkctxt.allocator.alloc(Buffer, in_flight) catch unreachable;
            for (self.buffers) |*b|
                b.init(self.buffer_size, .{ .storage_buffer_bit = true }, .sequential);

            // Since buffer will not reallocate (const size), we can map memory once
            self.data = vkctxt.allocator.alloc([]BufferType, in_flight) catch unreachable;
            for (self.data) |*d, ind| {
                d.ptr = @ptrCast([*]BufferType, @alignCast(@alignOf(BufferType), self.buffers[ind].allocation.mapped_memory));
                d.len = object_count;
            }
        }

        pub fn deinit(self: *SelfType) void {
            vkctxt.allocator.free(self.data);

            for (self.buffers) |*b|
                b.destroy();
            vkctxt.allocator.free(self.buffers);
        }
    };
}
