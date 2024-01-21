const std = @import("std");

const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const Image = @import("image.zig").Image;

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const ImageView = struct {
    vk_ref: vk.ImageView,

    image: *Image = undefined,

    pub fn init(self: *ImageView, image: *Image) void {
        self.image = image;

        const aspect_mask: vk.ImageAspectFlags = if (image.format == .d32_sfloat) .{ .depth_bit = true } else .{ .color_bit = true };

        const view_info: vk.ImageViewCreateInfo = .{
            .image = self.image.vk_ref,
            .view_type = .@"2d",
            .format = self.image.format,
            .subresource_range = .{
                .aspect_mask = aspect_mask,
                .level_count = 1,
                .layer_count = 1,
                .base_mip_level = 0,
                .base_array_layer = 0,
            },
            .flags = .{},
            .components = .{
                .r = .identity,
                .g = .identity,
                .b = .identity,
                .a = .identity,
            },
        };

        self.vk_ref = vkfn.d.createImageView(vkctxt.device, &view_info, null) catch |err| {
            printVulkanError("Can't create image view", err);
            return;
        };
    }

    pub fn destroy(self: *ImageView) void {
        vkfn.d.destroyImageView(vkctxt.device, self.vk_ref, null);
    }

    pub fn recreate(self: *ImageView) void {
        self.destroy();
        self.init(self.image);
    }
};
