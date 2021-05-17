const vk = @import("vulkan");
const std = @import("std");

usingnamespace @import("vulkan_wrapper.zig");

const printError = @import("../application/print_error.zig").printError;

pub const Swapchain = struct {
    swapchain: vk.SwapchainKHR,

    image_format: vk.Format,
    image_extent: vk.Extent2D,
    image_count: u32,

    images: []vk.Image,
    image_views: []vk.ImageView,
    render_pass: vk.RenderPass,
    framebuffers: []vk.Framebuffer,

    command_buffers: []vk.CommandBuffer,

    pub fn init(self: *Swapchain, context: *const VulkanContext, width: u32, height: u32) !void {
        const swapchain_support: SwapchainSupportDetails = context.getSwapchainSupport(&context.physical_device) catch unreachable;
        defer context.allocator.free(swapchain_support.formats);
        defer context.allocator.free(swapchain_support.present_modes);

        const surface_format: vk.SurfaceFormatKHR = chooseSwapSurfaceFormat(swapchain_support.formats);
        const present_mode: vk.PresentModeKHR = chooseSwapPresentMode(swapchain_support.present_modes);
        const extent: vk.Extent2D = chooseSwapExtent(&swapchain_support.capabilities, width, height);

        var image_count: u32 = swapchain_support.capabilities.min_image_count + 1;

        if (swapchain_support.capabilities.max_image_count > 0 and image_count > swapchain_support.capabilities.max_image_count) {
            image_count = swapchain_support.capabilities.max_image_count;
        }

        self.image_count = image_count;

        const queue_family_indices: [2]u32 = [_]u32{
            context.family_indices.graphics_family,
            context.family_indices.present_family,
        };
        const queue_concurrent: bool = queue_family_indices[0] != queue_family_indices[1];

        const create_info: vk.SwapchainCreateInfoKHR = .{
            .flags = .{},
            .surface = context.surface,

            .min_image_count = image_count,
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

        self.swapchain = context.vkd.createSwapchainKHR(context.device, create_info, null) catch |err| {
            printVulkanError("Can't create swapchain", err, context.allocator);
            return err;
        };

        self.image_format = surface_format.format;
        self.image_extent = extent;

        _ = context.vkd.getSwapchainImagesKHR(context.device, self.swapchain, &self.image_count, null) catch |err| {
            printVulkanError("Can't get image count for swapchain", err, context.allocator);
            return err;
        };
        self.images = context.allocator.alloc(vk.Image, self.image_count) catch {
            printError("Vulkan Resources", "Can't allocate images for swapchain on host");
            return error.HostAllocationError;
        };
        _ = context.vkd.getSwapchainImagesKHR(context.device, self.swapchain, &self.image_count, @ptrCast([*]vk.Image, &self.images)) catch |err| {
            printVulkanError("Can't get images for swapchain", err, context.allocator);
            return err;
        };
    }

    pub fn deinit(self: *Swapchain, context: *const VulkanContext) void {
        context.allocator.free(self.images);
    }

    fn chooseSwapSurfaceFormat(available_formats: []vk.SurfaceFormatKHR) vk.SurfaceFormatKHR {
        for (available_formats) |format| {
            if (format.format == .b8g8r8a8_unorm and format.color_space == .srgb_nonlinear_khr) {
                return format;
            }
        }

        return available_formats[0];
    }

    fn chooseSwapPresentMode(available_present_modes: []vk.PresentModeKHR) vk.PresentModeKHR {
        for (available_present_modes) |present_mode| {
            if (present_mode == .mailbox_khr) {
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
