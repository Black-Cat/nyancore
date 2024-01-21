const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const CommandPool = struct {
    vk_ref: vk.CommandPool,

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
        };
    }

    pub fn destroy(self: *CommandPool) void {
        vkfn.d.destroyCommandPool(vkctxt.device, self.vk_ref, null);
    }

    pub fn reset(self: *CommandPool) void {
        _ = vkfn.d.vkResetCommandPool(vkctxt.device, self.vk_ref, 0);
    }
};
