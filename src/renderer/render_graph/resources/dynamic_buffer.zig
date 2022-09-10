const vk = @import("../../../vk.zig");
const rg = @import("../render_graph.zig");

const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../../../vulkan_wrapper/vulkan_functions.zig");

const Buffer = @import("../../../vulkan_wrapper/buffer.zig").Buffer;

pub fn DynamicBuffer(comptime BufferType: type, usage: vk.BufferUsageFlags) type {
    return struct {
        const SelfType = DynamicBuffer(BufferType, usage);

        buffer: Buffer,
        data: [][]BufferType,
        data_offset: usize,
        single_buffer_size: usize,

        pub fn init(self: *SelfType, object_count: usize) void {
            const min_alignment: usize = @intCast(
                usize,
                if (usage.uniform_buffer_bit)
                    vkctxt.physical_device.device_properties.limits.min_uniform_buffer_offset_alignment
                else if (usage.storage_buffer_bit)
                    vkctxt.physical_device.device_properties.limits.min_storage_buffer_offset_alignment
                else
                    @compileError("Unsupported buffer usage"),
            );

            self.single_buffer_size = @sizeOf(BufferType) * object_count;

            const in_flight: usize = @intCast(usize, rg.global_render_graph.in_flight);
            self.data_offset = (self.single_buffer_size + min_alignment - 1) & ~(min_alignment - 1);
            const buffer_size: usize = self.data_offset * in_flight;

            self.buffer.init(buffer_size, usage, .sequential);

            // Since buffer will not reallocate (const size), we can map memory once
            self.data = vkctxt.allocator.alloc([]BufferType, in_flight) catch unreachable;
            for (self.data) |*d, ind| {
                d.ptr = @ptrCast([*]BufferType, @alignCast(@alignOf(BufferType), &@ptrCast([*]u8, self.buffer.allocation.mapped_memory)[self.data_offset * ind]));
                d.len = object_count;
            }
        }

        pub fn deinit(self: *SelfType) void {
            vkctxt.allocator.free(self.data);
            self.buffer.destroy();
        }
    };
}
