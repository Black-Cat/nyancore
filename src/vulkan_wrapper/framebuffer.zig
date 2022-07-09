const vk = @import("../vk.zig");
const std = @import("std");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const RenderPass = @import("render_pass.zig").RenderPass;
const Swapchain = @import("swapchain.zig").Swapchain;
const ViewportTexture = @import("../renderer/render_graph/resources/viewport_texture.zig").ViewportTexture;

pub const Framebuffer = struct {
    vk_ref: vk.Framebuffer,

    pub fn create(render_pass: *RenderPass, target: anytype) []Framebuffer {
        switch (@TypeOf(target)) {
            *Swapchain => return createFromSwapchain(render_pass, target),
            *ViewportTexture => return createFromViewportTexture(render_pass, target),
            else => @compileError("Unsupported target for frame buffer: " ++ @typeName(@TypeOf(target))),
        }
        unreachable;
    }

    pub fn createFromParams(render_pass: *RenderPass, count: usize, width: u32, height: u32, image_views: []vk.ImageView) []Framebuffer {
        var framebuffers: []Framebuffer = vkctxt.allocator.alloc(Framebuffer, count) catch unreachable;

        for (framebuffers) |*framebuffer, i| {
            const create_info: vk.FramebufferCreateInfo = .{
                .flags = .{},
                .render_pass = render_pass.vk_ref,
                .attachment_count = 1,
                .p_attachments = @ptrCast([*]const vk.ImageView, &image_views[i]),
                .width = width,
                .height = height,
                .layers = 1,
            };

            framebuffer.vk_ref = vkfn.d.createFramebuffer(vkctxt.device, create_info, null) catch |err| {
                printVulkanError("Can't create framebuffer from swapchain", err);
                return undefined;
            };
        }

        return framebuffers;
    }

    pub fn createFromSwapchain(render_pass: *RenderPass, swapchain: *Swapchain) []Framebuffer {
        return createFromParams(render_pass, swapchain.image_count, swapchain.image_extent.width, swapchain.image_extent.height, swapchain.image_views);
    }

    pub fn createFromViewportTexture(render_pass: *RenderPass, viewport_texture: *ViewportTexture) []Framebuffer {
        var image_views: []vk.ImageView = vkctxt.allocator.alloc(vk.ImageView, viewport_texture.textures.len) catch unreachable;
        defer vkctxt.allocator.free(image_views);

        for (image_views) |*iv, ind|
            iv.* = viewport_texture.textures[ind].view;

        return createFromParams(render_pass, viewport_texture.textures.len, viewport_texture.extent.width, viewport_texture.extent.height, image_views);
    }

    pub fn destroy(self: *Framebuffer) void {
        vkfn.d.destroyFramebuffer(vkctxt.device, self.vk_ref, null);
    }
};
