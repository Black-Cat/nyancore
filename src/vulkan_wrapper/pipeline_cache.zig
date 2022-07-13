const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const PipelineCache = struct {
    vk_ref: vk.PipelineCache,

    pub fn createEmpty() PipelineCache {
        const pipeline_cache_create_info: vk.PipelineCacheCreateInfo = .{
            .flags = .{},
            .initial_data_size = 0,
            .p_initial_data = undefined,
        };

        const pipeline_cache: vk.PipelineCache = vkfn.d.createPipelineCache(vkctxt.device, pipeline_cache_create_info, null) catch |err| {
            printVulkanError("Can't create pipeline cache", err);
            unreachable;
        };

        return .{ .vk_ref = pipeline_cache };
    }

    pub fn destroy(self: *const PipelineCache) void {
        vkfn.d.destroyPipelineCache(vkctxt.device, self.vk_ref, null);
    }
};
