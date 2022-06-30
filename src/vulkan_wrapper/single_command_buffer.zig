const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

const CommandBuffer = @import("command_buffer.zig").CommandBuffer;
const CommandBuffers = @import("command_buffers.zig").CommandBuffers;
const CommandPool = @import("command_pool.zig").CommandPool;

pub const SingleCommandBuffer = struct {
    command_buffers: CommandBuffers,
    command_buffer: CommandBuffer,

    pub fn allocate(pool: *CommandPool) !SingleCommandBuffer {
        var scb: SingleCommandBuffer = undefined;
        scb.command_buffers = try CommandBuffers.allocate(pool, 1);
        scb.command_buffer = scb.command_buffers.getBuffer(0);
        return scb;
    }

    pub fn submit(self: *SingleCommandBuffer, queue: vk.Queue) void {
        const submit_info: vk.SubmitInfo = .{
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &self.command_buffer.vk_ref),
            .wait_semaphore_count = 0,
            .p_wait_semaphores = undefined,
            .p_wait_dst_stage_mask = undefined,
            .signal_semaphore_count = 0,
            .p_signal_semaphores = undefined,
        };

        vkfn.d.queueSubmit(queue, 1, @ptrCast([*]const vk.SubmitInfo, &submit_info), .null_handle) catch |err| {
            printVulkanError("Can't submit queue", err);
        };
        vkfn.d.queueWaitIdle(queue) catch |err| {
            printVulkanError("Can't wait for queue", err);
        };

        self.command_buffers.freeVulkan();
        self.command_buffers.free();
    }
};
