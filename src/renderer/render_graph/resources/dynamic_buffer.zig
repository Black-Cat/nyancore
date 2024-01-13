const vk = @import("../../../vk.zig");
const rg = @import("../render_graph.zig");

const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../../../vulkan_wrapper/vulkan_functions.zig");

const Buffer = @import("../../../vulkan_wrapper/buffer.zig").Buffer;

pub fn DynamicBuffer(comptime BufferType: type) type {
    return struct {
        const SelfType = DynamicBuffer(BufferType);

        buffer: Buffer,
        data: []*BufferType,
        data_offset: usize,

        pub fn init(self: *SelfType) void {
            const min_alignment: usize = @intCast(vkctxt.physical_device.device_properties.limits.min_uniform_buffer_offset_alignment);

            const in_flight: usize = @intCast(rg.global_render_graph.in_flight);
            self.data_offset = (@sizeOf(BufferType) + min_alignment - 1) & ~(min_alignment - 1);
            const buffer_size: usize = self.data_offset * in_flight;

            self.buffer.init(buffer_size, .{ .uniform_buffer_bit = true }, .sequential);

            // Since buffer will not reallocate (const size), we can map memory once
            self.data = vkctxt.allocator.alloc(*BufferType, in_flight) catch unreachable;
            for (self.data, 0..) |*d, ind|
                d.* = @ptrCast(@alignCast(&@as([*]u8, @ptrCast(self.buffer.allocation.mapped_memory))[self.data_offset * ind]));
        }

        pub fn deinit(self: *SelfType) void {
            vkctxt.allocator.free(self.data);
            self.buffer.destroy();
        }
    };
}
