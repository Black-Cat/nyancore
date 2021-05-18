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

    command_pool: vk.CommandPool,
    command_buffers: []vk.CommandBuffer,

    pub fn init(self: *Swapchain, context: *const VulkanContext, width: u32, height: u32, command_pool: vk.CommandPool) !void {
        self.command_pool = command_pool;

        try self.createSwapchain(context, width, height);
        try self.createImageViews(context);
        try self.createRenderPass(context);
        try self.createSwapBuffers(context);
        try self.createCommandBuffers(context);
    }

    pub fn deinit(self: *Swapchain, context: *const VulkanContext) void {
        self.cleanup(context);
    }

    pub fn recreate(self: *Swapchain, context: *const VulkanContext, width: u32, height: u32) !void {
        self.cleanup(context);
        try self.init(context, width, height, self.command_pool);
    }

    fn cleanup(self: *Swapchain, context: *const VulkanContext) void {
        for (self.image_views) |image_view| {
            context.vkd.destroyImageView(context.device, image_view, null);
        }

        for (self.framebuffers) |framebuffer| {
            context.vkd.destroyFramebuffer(context.device, framebuffer, null);
        }

        context.allocator.free(self.image_views);
        context.allocator.free(self.framebuffers);

        context.vkd.freeCommandBuffers(context.device, self.command_pool, self.image_count, self.command_buffers.ptr);

        context.vkd.destroyRenderPass(context.device, self.render_pass, null);
        context.vkd.destroySwapchainKHR(context.device, self.swapchain, null);
    }

    fn createSwapchain(self: *Swapchain, context: *const VulkanContext, width: u32, height: u32) !void {
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
            printError("Vulkan Wrapper", "Can't allocate images for swapchain on host");
            return error.HostAllocationError;
        };
        _ = context.vkd.getSwapchainImagesKHR(context.device, self.swapchain, &self.image_count, self.images.ptr) catch |err| {
            printVulkanError("Can't get images for swapchain", err, context.allocator);
            return err;
        };
    }

    fn createImageViews(self: *Swapchain, context: *const VulkanContext) !void {
        self.image_views = context.allocator.alloc(vk.ImageView, self.image_count) catch {
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

            image_view.* = context.vkd.createImageView(context.device, create_info, null) catch |err| {
                printVulkanError("Can't create image view", err, context.allocator);
                return err;
            };
        }
    }

    fn createRenderPass(self: *Swapchain, context: *const VulkanContext) !void {
        const color_attachment: vk.AttachmentDescription = .{
            .flags = .{},
            .format = self.image_format,
            .samples = .{
                .@"1_bit" = true,
            },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .@"undefined",
            .final_layout = .present_src_khr,
        };

        const color_attachment_ref: vk.AttachmentReference = .{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        };

        const subpass: vk.SubpassDescription = .{
            .flags = .{},
            .pipeline_bind_point = .graphics,
            .color_attachment_count = 1,
            .p_color_attachments = @ptrCast([*]const vk.AttachmentReference, &color_attachment_ref),

            .input_attachment_count = 0,
            .p_input_attachments = undefined,
            .p_resolve_attachments = undefined,
            .p_depth_stencil_attachment = undefined,
            .preserve_attachment_count = 0,
            .p_preserve_attachments = undefined,
        };

        const render_pass_create_info: vk.RenderPassCreateInfo = .{
            .flags = .{},
            .attachment_count = 1,
            .p_attachments = @ptrCast([*]const vk.AttachmentDescription, &color_attachment),
            .subpass_count = 1,
            .p_subpasses = @ptrCast([*]const vk.SubpassDescription, &subpass),
            .dependency_count = 0,
            .p_dependencies = undefined,
        };

        self.render_pass = context.vkd.createRenderPass(context.device, render_pass_create_info, null) catch |err| {
            printVulkanError("Can't create render pass for swapchain", err, context.allocator);
            return err;
        };
    }

    fn createSwapBuffers(self: *Swapchain, context: *const VulkanContext) !void {
        self.framebuffers = context.allocator.alloc(vk.Framebuffer, self.image_count) catch {
            printError("Vulkan Wrapper", "Can't allocate framebuffers for swapchain in host");
            return error.HostAllocationError;
        };

        for (self.framebuffers) |*framebuffer, i| {
            const create_info: vk.FramebufferCreateInfo = .{
                .flags = .{},
                .render_pass = self.render_pass,
                .attachment_count = 1,
                .p_attachments = @ptrCast([*]const vk.ImageView, &self.image_views[i]),
                .width = self.image_extent.width,
                .height = self.image_extent.height,
                .layers = 1,
            };

            framebuffer.* = context.vkd.createFramebuffer(context.device, create_info, null) catch |err| {
                printVulkanError("Can't create framebuffer for swapchain", err, context.allocator);
                return err;
            };
        }
    }

    fn createCommandBuffers(self: *Swapchain, context: *const VulkanContext) !void {
        self.command_buffers = context.allocator.alloc(vk.CommandBuffer, self.image_count) catch {
            printError("Vulkan Wrapper", "Can't allocate command buffers for swapchain on host");
            return error.HostAllocationError;
        };

        const alloc_info: vk.CommandBufferAllocateInfo = .{
            .command_pool = self.command_pool,
            .level = .primary,
            .command_buffer_count = self.image_count,
        };

        context.vkd.allocateCommandBuffers(context.device, alloc_info, @ptrCast([*]vk.CommandBuffer, &self.command_buffers)) catch |err| {
            printVulkanError("Can't allocate command buffers for swapchain", err, context.allocator);
            return err;
        };
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
