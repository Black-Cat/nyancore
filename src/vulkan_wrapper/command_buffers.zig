const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const CommandPool = @import("command_pool.zig").CommandPool;
const CommandBuffer = @import("command_buffer.zig").CommandBuffer;

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const CommandBuffers = struct {
    vk_ref: []vk.CommandBuffer,
    command_pool: *CommandPool,

    pub fn allocate(pool: *CommandPool, count: u32) !CommandBuffers {
        var buffers: CommandBuffers = undefined;
        buffers.command_pool = pool;

        buffers.vk_ref = vkctxt.allocator.alloc(vk.CommandBuffer, count) catch unreachable;
        errdefer vkctxt.allocator.free(buffers.vk_ref);

        const command_buffer_info: vk.CommandBufferAllocateInfo = .{
            .level = .primary,
            .command_pool = pool.vk_ref,
            .command_buffer_count = count,
        };

        vkfn.d.allocateCommandBuffers(vkctxt.device, command_buffer_info, buffers.vk_ref.ptr) catch |err| {
            printVulkanError("Can't allocate command buffers", err);
            return err;
        };

        return buffers;
    }

    pub fn freeVulkan(self: *CommandBuffers) void {
        vkfn.d.vkFreeCommandBuffers(vkctxt.device, self.command_pool.vk_ref, @intCast(u32, self.vk_ref.len), self.vk_ref.ptr);
    }

    pub fn free(self: *CommandBuffers) void {
        vkctxt.allocator.free(self.vk_ref);
    }

    pub fn getBuffer(self: *CommandBuffers, index: usize) CommandBuffer {
        return .{
            .vk_ref = self.vk_ref[index],
        };
    }
};
