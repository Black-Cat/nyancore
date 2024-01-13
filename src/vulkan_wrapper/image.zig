const std = @import("std");

const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const VmaAllocation = @import("vma_allocation.zig").VmaAllocation;

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const Image = struct {
    vk_ref: vk.Image,

    allocation: VmaAllocation,

    extent: vk.Extent3D,
    format: vk.Format,
    layout: vk.ImageLayout,
    usage_flags: vk.ImageUsageFlags,

    pub fn init(self: *Image, format: vk.Format, usage_flags: vk.ImageUsageFlags, extent: vk.Extent3D, layout: vk.ImageLayout) void {
        self.format = format;
        self.usage_flags = usage_flags;
        self.layout = layout;
        self.extent = extent;

        const image_info: vk.ImageCreateInfo = .{
            .image_type = if (extent.depth > 1) .@"3d" else .@"2d",
            .format = format,
            .extent = extent,
            .mip_levels = 1,
            .array_layers = 1,
            .samples = .{
                .@"1_bit" = true,
            },
            .tiling = .optimal,
            .usage = usage_flags,
            .sharing_mode = .exclusive,
            .initial_layout = layout,
            .flags = .{},
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        self.allocation = .{};
        self.allocation.create(image_info, &self.vk_ref);
    }

    pub fn destroy(self: *Image) void {
        vkfn.d.destroyImage(vkctxt.device, self.vk_ref, null);
        self.allocation.free();
    }

    pub fn resize(self: *Image, extent: vk.Extent3D) void {
        self.destroy();
        self.init(self.format, self.usage_flags, extent, self.layout);
    }

    pub fn transitionImageLayout(self: *Image, command_buffer: vk.CommandBuffer, new_layout: vk.ImageLayout) void {
        if (self.layout == new_layout)
            return;

        var barrier: vk.ImageMemoryBarrier = .{
            .old_layout = self.layout,
            .new_layout = new_layout,

            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,

            .image = self.vk_ref,
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },

            .src_access_mask = imageLayoutToAccessMask(self.layout),
            .dst_access_mask = imageLayoutToAccessMask(new_layout),
        };

        const source_stage: vk.PipelineStageFlags = imageLayoutToStage(self.layout);
        const dst_stage: vk.PipelineStageFlags = imageLayoutToStage(new_layout);

        vkfn.d.cmdPipelineBarrier(
            command_buffer,
            source_stage,
            dst_stage,
            .{},
            0,
            undefined,
            0,
            undefined,
            1,
            @ptrCast(&barrier),
        );
    }

    fn imageLayoutToStage(layout: vk.ImageLayout) vk.PipelineStageFlags {
        return switch (layout) {
            .undefined => .{ .top_of_pipe_bit = true },
            .shader_read_only_optimal => .{ .fragment_shader_bit = true },
            .transfer_dst_optimal => .{ .transfer_bit = true },
            else => @panic("Unsuported image layout stage"),
        };
    }

    fn imageLayoutToAccessMask(layout: vk.ImageLayout) vk.AccessFlags {
        return switch (layout) {
            .undefined => .{},
            .shader_read_only_optimal => .{ .shader_read_bit = true },
            .transfer_dst_optimal => .{ .transfer_write_bit = true },
            else => @panic("Unsuported image layout access mask"),
        };
    }
};
