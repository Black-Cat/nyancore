const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const CommandBuffer = struct {
    vk_ref: vk.CommandBuffer,

    pub fn beginSingleTimeCommands(self: *CommandBuffer) void {
        const begin_info: vk.CommandBufferBeginInfo = .{
            .flags = .{
                .one_time_submit_bit = true,
            },
            .p_inheritance_info = undefined,
        };

        vkfn.d.beginCommandBuffer(self.vk_ref, &begin_info) catch |err| {
            printVulkanError("Can't begin command buffer", err);
        };
    }

    pub fn endSingleTimeCommands(self: *CommandBuffer) void {
        vkfn.d.endCommandBuffer(self.vk_ref) catch |err| {
            printVulkanError("Can't end command buffer", err);
            return;
        };
    }

    pub fn reset(self: *CommandBuffer) void {
        vkfn.d.resetCommandBuffer(self.vk_ref, .{}) catch |err| {
            printVulkanError("Can't reset command buffer", err);
        };
    }
};
