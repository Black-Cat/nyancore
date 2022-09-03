const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

const CommandBuffer = @import("command_buffer.zig").CommandBuffer;
const DescriptorPool = @import("descriptor_pool.zig").DescriptorPool;
const PipelineLayout = @import("pipeline_layout.zig").PipelineLayout;

pub const DescriptorSets = struct {
    vk_ref: []vk.DescriptorSet,

    pub fn bind(self: *DescriptorSets, bind_point: vk.PipelineBindPoint, command_buffer: *CommandBuffer, pipeline_layout: *PipelineLayout) void {
        vkfn.d.cmdBindDescriptorSets(
            command_buffer.vk_ref,
            bind_point,
            pipeline_layout.vk_ref,
            0,
            @intCast(u32, self.vk_ref.len),
            @ptrCast([*]const vk.DescriptorSet, self.vk_ref.ptr),
            0,
            undefined,
        );
    }

    pub fn init(self: *DescriptorSets, pool: *DescriptorPool, layouts: []vk.DescriptorSetLayout) void {
        const descriptor_set_allocate_info: vk.DescriptorSetAllocateInfo = .{
            .descriptor_pool = pool.vk_ref,
            .p_set_layouts = @ptrCast([*]const vk.DescriptorSetLayout, layouts.ptr),
            .descriptor_set_count = @intCast(u32, layouts.len),
        };

        self.vk_ref = vkctxt.allocator.alloc(vk.DescriptorSet, layouts.len) catch unreachable;

        vkfn.d.allocateDescriptorSets(vkctxt.device, descriptor_set_allocate_info, @ptrCast([*]vk.DescriptorSet, self.vk_ref.ptr)) catch |err| {
            printVulkanError("Can't allocate descriptor sets", err);
        };
    }

    pub fn deinit(self: *DescriptorSets) void {
        vkctxt.allocator.free(self.vk_ref);
    }

    pub fn write(self: *DescriptorSets, index: usize, image_infos: []vk.DescriptorImageInfo) void {
        const write_descriptor_set: vk.WriteDescriptorSet = .{
            .dst_set = self.vk_ref[index],
            .descriptor_type = .combined_image_sampler,
            .dst_binding = 0,
            .p_image_info = @ptrCast([*]const vk.DescriptorImageInfo, image_infos.ptr),
            .descriptor_count = 1,
            .dst_array_element = 0,
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        };

        vkfn.d.updateDescriptorSets(vkctxt.device, 1, @ptrCast([*]const vk.WriteDescriptorSet, &write_descriptor_set), 0, undefined);
    }
};
