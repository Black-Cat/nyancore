const vk = @import("../vk.zig");
const std = @import("std");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

pub const Semaphore = struct {
    vk_ref: vk.Semaphore,

    pub fn create() Semaphore {
        const semaphore_info: vk.SemaphoreCreateInfo = .{
            .flags = .{},
        };

        const vk_ref: vk.Semaphore = vkfn.d.createSemaphore(vkctxt.device, &semaphore_info, null) catch |err| {
            printVulkanError("Can't create semaphore", err);
            unreachable;
        };

        return .{
            .vk_ref = vk_ref,
        };
    }

    pub fn destroy(self: *Semaphore) void {
        vkfn.d.destroySemaphore(vkctxt.device, self.vk_ref, null);
    }
};
