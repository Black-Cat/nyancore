const std = @import("std");

const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const VmaAllocation = @import("vma_allocation.zig").VmaAllocation;

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const Image = struct {
    vk_ref: vk.Image,

    allocation: VmaAllocation,

    format: vk.Format,
    usage_flags: vk.ImageUsageFlags,

    pub fn init(self: *Image, format: vk.Format, usage_flags: vk.ImageUsageFlags, extent: vk.Extent3D) void {
        self.format = format;
        self.usage_flags = usage_flags;

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
            .initial_layout = .@"undefined",
            .flags = .{},
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        self.allocation = .{};
        self.allocation.create(image_info, &self.vk_ref);
    }

    pub fn destroy(self: *Image) void {
        vkfn.d.vkDestroyImage(vkctxt.device, self.vk_ref, null);
        self.allocation.free();
    }

    pub fn resize(self: *Image, extent: vk.Extent3D) void {
        self.destroy();
        self.init(self.format, self.usage_flags, extent);
    }
};
