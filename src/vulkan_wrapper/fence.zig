const vk = @import("../vk.zig");
const std = @import("std");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

pub const Fence = struct {
    vk_ref: vk.Fence,

    pub fn create() Fence {
        const fence_info: vk.FenceCreateInfo = .{
            .flags = .{
                .signaled_bit = true,
            },
        };

        var res: Fence = undefined;

        res.vk_ref = vkfn.d.createFence(vkctxt.device, &fence_info, null) catch |err| {
            printVulkanError("Can't create fence", err);
            unreachable;
        };

        return res;
    }

    pub fn destroy(self: *Fence) void {
        vkfn.d.destroyFence(vkctxt.device, self.vk_ref, null);
    }

    pub fn waitFor(self: *const Fence) void {
        _ = vkfn.d.waitForFences(vkctxt.device, 1, @ptrCast(&self.vk_ref), vk.TRUE, std.math.maxInt(u64)) catch |err| {
            printVulkanError("Error waiting for fence", err);
            unreachable;
        };
    }

    pub fn reset(self: *Fence) void {
        vkfn.d.resetFences(vkctxt.device, 1, @ptrCast(&self.vk_ref)) catch |err| {
            printVulkanError("Can't reset fence", err);
        };
    }
};
