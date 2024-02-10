const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

const CommandBuffer = @import("command_buffer.zig").CommandBuffer;
const CommandPool = @import("command_pool.zig").CommandPool;

pub const SingleCommandBuffer = struct {
    command_buffer: CommandBuffer,
    command_pool: *CommandPool,

    pub fn allocate(pool: *CommandPool) !SingleCommandBuffer {
        var scb: SingleCommandBuffer = undefined;
        scb.command_pool = pool;

        const command_buffer_info: vk.CommandBufferAllocateInfo = .{
            .level = .primary,
            .command_pool = pool.vk_ref,
            .command_buffer_count = 1,
        };

        vkfn.d.allocateCommandBuffers(vkctxt.device, &command_buffer_info, @ptrCast(&scb.command_buffer.vk_ref)) catch |err| {
            printVulkanError("Can't allocate command buffers", err);
        };

        return scb;
    }

    pub fn submit(self: *SingleCommandBuffer, queue: vk.Queue) void {
        const submit_info: vk.SubmitInfo = .{
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&self.command_buffer.vk_ref),
            .wait_semaphore_count = 0,
            .p_wait_semaphores = undefined,
            .p_wait_dst_stage_mask = undefined,
            .signal_semaphore_count = 0,
            .p_signal_semaphores = undefined,
        };

        vkfn.d.queueSubmit(queue, 1, @ptrCast(&submit_info), .null_handle) catch |err| {
            printVulkanError("Can't submit queue", err);
        };
        vkfn.d.queueWaitIdle(queue) catch |err| {
            printVulkanError("Can't wait for queue", err);
        };

        vkfn.d.freeCommandBuffers(vkctxt.device, self.command_pool.vk_ref, 1, @ptrCast(&self.command_buffer.vk_ref));
    }
};
