const vk = @import("../vk.zig");
const std = @import("std");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printError = @import("../application/print_error.zig").printError;
const printVulkanError = @import("../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const RGResource = @import("../renderer/render_graph/render_graph_resource.zig").RGResource;
const PhysicalDevice = @import("physical_device.zig").PhysicalDevice;
const SwapchainSupportDetails = PhysicalDevice.SwapchainSupportDetails;
const Framebuffer = @import("framebuffer.zig").Framebuffer;

pub const Swapchain = struct {
    rg_resource: RGResource,

    swapchain: vk.SwapchainKHR,

    vsync: bool,

    image_format: vk.Format,
    image_extent: vk.Extent2D,
    image_count: u32,

    images: []vk.Image,
    image_views: []vk.ImageView,

    framebuffers: std.ArrayList(*[]Framebuffer),

    pub fn init(self: *Swapchain, width: u32, height: u32, images_count: u32, vsync: bool) !void {
        self.image_count = images_count;
        self.vsync = vsync;
        self.framebuffers = std.ArrayList(*[]Framebuffer).init(vkctxt.allocator);

        try self.createSwapchain(width, height);
        try self.createImageViews();
    }

    pub fn deinit(self: *Swapchain) void {
        self.framebuffers.deinit();
        self.cleanup();
    }

    pub fn recreate(self: *Swapchain, width: u32, height: u32) !void {
        self.cleanup();
        try self.createSwapchain(width, height);
        try self.createImageViews();

        for (self.framebuffers.items) |fbs|
            Framebuffer.recreateFramebuffers(fbs, self);
    }

    pub fn recreateWithSameSize(self: *Swapchain) !void {
        try self.recreate(self.image_extent.width, self.image_extent.height);
    }

    fn cleanup(self: *Swapchain) void {
        for (self.image_views) |image_view| {
            vkfn.d.destroyImageView(vkctxt.device, image_view, null);
        }

        vkctxt.allocator.free(self.image_views);

        vkfn.d.destroySwapchainKHR(vkctxt.device, self.swapchain, null);
    }

    fn createSwapchain(self: *Swapchain, width: u32, height: u32) !void {
        const swapchain_support: SwapchainSupportDetails = PhysicalDevice.getSwapchainSupport(vkctxt.physical_device.vk_reference) catch unreachable;
        defer vkctxt.allocator.free(swapchain_support.formats);
        defer vkctxt.allocator.free(swapchain_support.present_modes);

        const surface_format: vk.SurfaceFormatKHR = chooseSwapSurfaceFormat(swapchain_support.formats);
        const present_mode: vk.PresentModeKHR = chooseSwapPresentMode(swapchain_support.present_modes, self.vsync);
        const extent: vk.Extent2D = chooseSwapExtent(&swapchain_support.capabilities, width, height);

        var image_count: u32 = self.image_count;
        if (image_count < swapchain_support.capabilities.min_image_count)
            image_count = swapchain_support.capabilities.min_image_count;
        if (image_count < swapchain_support.capabilities.max_image_count)
            image_count = swapchain_support.capabilities.max_image_count;
        self.image_count = image_count;

        const queue_family_indices: [2]u32 = [_]u32{
            vkctxt.physical_device.family_indices.graphics_family,
            vkctxt.physical_device.family_indices.present_family,
        };
        const queue_concurrent: bool = queue_family_indices[0] != queue_family_indices[1];

        const create_info: vk.SwapchainCreateInfoKHR = .{
            .flags = .{},
            .surface = vkctxt.surface,

            .min_image_count = self.image_count,
            .image_format = surface_format.format,
            .image_color_space = surface_format.color_space,
            .image_extent = extent,
            .image_array_layers = 1,
            .image_usage = .{
                .color_attachment_bit = true,
            },

            .pre_transform = swapchain_support.capabilities.current_transform,
            .composite_alpha = .{
                .opaque_bit_khr = true,
            },
            .present_mode = present_mode,
            .clipped = vk.TRUE,
            .old_swapchain = .null_handle,

            .image_sharing_mode = if (queue_concurrent) .concurrent else .exclusive,
            .queue_family_index_count = if (queue_concurrent) queue_family_indices.len else 0,
            .p_queue_family_indices = @ptrCast([*]const u32, &queue_family_indices),
        };

        self.swapchain = vkfn.d.createSwapchainKHR(vkctxt.device, create_info, null) catch |err| {
            printVulkanError("Can't create swapchain", err);
            return err;
        };

        self.image_format = surface_format.format;
        self.image_extent = extent;

        _ = vkfn.d.getSwapchainImagesKHR(vkctxt.device, self.swapchain, &self.image_count, null) catch |err| {
            printVulkanError("Can't get image count for swapchain", err);
            return err;
        };
        self.images = vkctxt.allocator.alloc(vk.Image, self.image_count) catch {
            printError("Vulkan Wrapper", "Can't allocate images for swapchain on host");
            return error.HostAllocationError;
        };
        _ = vkfn.d.getSwapchainImagesKHR(vkctxt.device, self.swapchain, &self.image_count, self.images.ptr) catch |err| {
            printVulkanError("Can't get images for swapchain", err);
            return err;
        };
    }

    fn createImageViews(self: *Swapchain) !void {
        self.image_views = vkctxt.allocator.alloc(vk.ImageView, self.image_count) catch {
            printError("Vulkan Wrapper", "Can't allocate image views for swapchain on host");
            return error.HostAllocationError;
        };

        for (self.image_views) |*image_view, i| {
            const create_info: vk.ImageViewCreateInfo = .{
                .flags = .{},
                .image = self.images[i],
                .view_type = .@"2d",
                .format = self.image_format,

                .components = .{
                    .r = .identity,
                    .g = .identity,
                    .b = .identity,
                    .a = .identity,
                },

                .subresource_range = .{
                    .aspect_mask = .{
                        .color_bit = true,
                    },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
            };

            image_view.* = vkfn.d.createImageView(vkctxt.device, create_info, null) catch |err| {
                printVulkanError("Can't create image view", err);
                return err;
            };
        }
    }

    fn chooseSwapSurfaceFormat(available_formats: []vk.SurfaceFormatKHR) vk.SurfaceFormatKHR {
        for (available_formats) |format| {
            if (format.format == .r8g8b8a8_unorm and format.color_space == .srgb_nonlinear_khr) {
                return format;
            }
        }

        return available_formats[0];
    }

    fn chooseSwapPresentMode(available_present_modes: []vk.PresentModeKHR, vsync: bool) vk.PresentModeKHR {
        const prefered_modes: []const vk.PresentModeKHR = if (vsync)
            &.{.mailbox_khr}
        else
            &.{.immediate_khr};

        for (prefered_modes) |prefered_mode| {
            for (available_present_modes) |present_mode| {
                if (present_mode == prefered_mode)
                    return present_mode;
            }
        }

        return .fifo_khr;
    }

    fn chooseSwapExtent(capabilities: *const vk.SurfaceCapabilitiesKHR, width: u32, height: u32) vk.Extent2D {
        if (capabilities.current_extent.width != comptime std.math.maxInt(u32)) {
            return capabilities.current_extent;
        }

        const actual_extent: vk.Extent2D = .{
            .width = std.math.clamp(width, capabilities.min_image_extent.width, capabilities.max_image_extent.width),
            .height = std.math.clamp(height, capabilities.min_image_extent.height, capabilities.max_image_extent.height),
        };

        return actual_extent;
    }
};
