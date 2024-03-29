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
            @intCast(self.vk_ref.len),
            @ptrCast(self.vk_ref.ptr),
            0,
            undefined,
        );
    }

    pub fn init(self: *DescriptorSets, pool: *DescriptorPool, layouts: []const vk.DescriptorSetLayout, count: usize) void {
        const descriptor_set_allocate_info: vk.DescriptorSetAllocateInfo = .{
            .descriptor_pool = pool.vk_ref,
            .p_set_layouts = @ptrCast(layouts.ptr),
            .descriptor_set_count = @intCast(count),
        };

        self.vk_ref = vkctxt.allocator.alloc(vk.DescriptorSet, count) catch unreachable;

        vkfn.d.allocateDescriptorSets(vkctxt.device, &descriptor_set_allocate_info, @ptrCast(self.vk_ref.ptr)) catch |err| {
            printVulkanError("Can't allocate descriptor sets", err);
        };
    }

    pub fn deinit(self: *DescriptorSets) void {
        vkctxt.allocator.free(self.vk_ref);
    }

    pub fn write(self: *DescriptorSets, index: usize, image_infos: []const vk.DescriptorImageInfo) void {
        const write_descriptor_set: vk.WriteDescriptorSet = .{
            .dst_set = self.vk_ref[index],
            .descriptor_type = .combined_image_sampler,
            .dst_binding = 0,
            .p_image_info = @ptrCast(image_infos.ptr),
            .descriptor_count = 1,
            .dst_array_element = 0,
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        };

        vkfn.d.updateDescriptorSets(vkctxt.device, 1, @ptrCast(&write_descriptor_set), 0, undefined);
    }

    pub fn writeBuffer(dst_set: vk.DescriptorSet, dst_binding: u32, descriptor_type: vk.DescriptorType, buffer_infos: []vk.DescriptorBufferInfo) void {
        const write_descriptor_set: vk.WriteDescriptorSet = .{
            .dst_set = dst_set,
            .descriptor_type = descriptor_type,
            .dst_binding = dst_binding,
            .p_image_info = undefined,
            .descriptor_count = 1,
            .dst_array_element = 0,
            .p_buffer_info = @ptrCast(buffer_infos.ptr),
            .p_texel_buffer_view = undefined,
        };

        vkfn.d.updateDescriptorSets(vkctxt.device, 1, @ptrCast(&write_descriptor_set), 0, undefined);
    }

    pub fn writeBufferAll(self: *DescriptorSets, dst_binding: u32, descriptor_type: vk.DescriptorType, infos: []vk.DescriptorBufferInfo) void {
        for (self.vk_ref) |ds|
            writeBuffer(ds, dst_binding, descriptor_type, infos);
    }
};
