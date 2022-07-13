const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const PipelineLayout = struct {
    vk_ref: vk.PipelineLayout,

    pub fn create(descriptors: []vk.DescriptorSetLayout, push_constants: []const vk.PushConstantRange) PipelineLayout {
        const create_info: vk.PipelineLayoutCreateInfo = .{
            .set_layout_count = @intCast(u32, descriptors.len),
            .p_set_layouts = if (descriptors.len > 0) @ptrCast([*]const vk.DescriptorSetLayout, descriptors.ptr) else undefined,
            .push_constant_range_count = @intCast(u32, push_constants.len),
            .p_push_constant_ranges = if (push_constants.len > 0) @ptrCast([*]const vk.PushConstantRange, push_constants.ptr) else undefined,
            .flags = .{},
        };

        const pipeline_layout: vk.PipelineLayout = vkfn.d.createPipelineLayout(vkctxt.device, create_info, null) catch |err| {
            printVulkanError("Can't create pipeline layout", err);
            unreachable;
        };

        return .{ .vk_ref = pipeline_layout };
    }

    pub fn destroy(self: *const PipelineLayout) void {
        vkfn.d.destroyPipelineLayout(vkctxt.device, self.vk_ref, null);
    }
};
