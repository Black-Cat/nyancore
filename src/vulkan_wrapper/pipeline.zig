const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const Pipeline = struct {
    vk_ref: vk.Pipeline,

    pub fn destroy(self: *const Pipeline) void {
        vkfn.d.destroyPipeline(vkctxt.device, self.vk_ref, null);
    }
};
