const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const CommandBuffer = @import("command_buffer.zig").CommandBuffer;

pub const CommandPool = struct {
    vk_ref: vk.CommandPool,
    buffers: ?[]vk.CommandBuffer,

    pub fn create(family_index: u32) !CommandPool {
        const pool_info: vk.CommandPoolCreateInfo = .{
            .queue_family_index = family_index,
            .flags = .{
                .reset_command_buffer_bit = true,
            },
        };

        const pool: vk.CommandPool = vkfn.d.createCommandPool(vkctxt.device, &pool_info, null) catch |err| {
            printVulkanError("Can't create command pool", err);
            return err;
        };

        return CommandPool{
            .vk_ref = pool,
            .buffers = null,
        };
    }

    pub fn destroy(self: *CommandPool) void {
        if (self.buffers) |_|
            self.freeBuffers();
        vkfn.d.destroyCommandPool(vkctxt.device, self.vk_ref, null);
    }

    pub fn reset(self: *CommandPool) void {
        vkfn.d.resetCommandPool(vkctxt.device, self.vk_ref, .{}) catch |err| {
            printVulkanError("Can't reset command pool", err);
        };
    }

    pub fn allocateBuffers(self: *CommandPool, count: u32) void {
        if (self.buffers) |_|
            self.freeBuffers();

        self.buffers = vkctxt.allocator.alloc(vk.CommandBuffer, count) catch unreachable;
        errdefer vkctxt.allocator.free(self.buffers);

        const command_buffer_info: vk.CommandBufferAllocateInfo = .{
            .level = .primary,
            .command_pool = self.vk_ref,
            .command_buffer_count = count,
        };

        vkfn.d.allocateCommandBuffers(vkctxt.device, &command_buffer_info, self.buffers.?.ptr) catch |err| {
            printVulkanError("Can't allocate command buffers", err);
        };
    }

    pub fn freeBuffers(self: *CommandPool) void {
        vkfn.d.freeCommandBuffers(vkctxt.device, self.vk_ref, @intCast(self.buffers.?.len), self.buffers.?.ptr);
        vkctxt.allocator.free(self.buffers.?);
        self.buffers = null;
    }

    pub fn getBuffer(self: *CommandPool, index: usize) CommandBuffer {
        return .{
            .vk_ref = self.buffers.?[index],
        };
    }
};
