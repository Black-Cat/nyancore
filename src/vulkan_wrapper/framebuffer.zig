const vk = @import("../vk.zig");
const std = @import("std");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const RenderPass = @import("render_pass.zig").RenderPass;
const Swapchain = @import("swapchain.zig").Swapchain;
const ViewportTexture = @import("../renderer/render_graph/resources/viewport_texture.zig").ViewportTexture;
const ImageView = @import("image_view.zig").ImageView;

pub const Framebuffer = struct {
    vk_ref: vk.Framebuffer,
    render_pass: *RenderPass,

    pub fn create(render_pass: *RenderPass, target: anytype, image_views: []ImageView) []Framebuffer {
        var vk_image_views: []vk.ImageView = vkctxt.allocator.alloc(vk.ImageView, image_views.len) catch unreachable;
        defer vkctxt.allocator.free(vk_image_views);

        for (vk_image_views, image_views) |*viv, *iv|
            viv.* = iv.vk_ref;

        switch (@TypeOf(target)) {
            *Swapchain => return createFromSwapchain(render_pass, target, vk_image_views),
            *ViewportTexture => return createFromViewportTexture(render_pass, target, vk_image_views),
            else => @compileError("Unsupported target for frame buffer: " ++ @typeName(@TypeOf(target))),
        }
        unreachable;
    }

    pub fn createFromParams(
        render_pass: *RenderPass,
        count: usize,
        width: u32,
        height: u32,
        target_image_views: []vk.ImageView,
        image_views: []vk.ImageView,
    ) []Framebuffer {
        var framebuffers: []Framebuffer = vkctxt.allocator.alloc(Framebuffer, count) catch unreachable;

        var frame_image_views: []vk.ImageView = vkctxt.allocator.alloc(vk.ImageView, image_views.len + 1) catch unreachable;
        defer vkctxt.allocator.free(frame_image_views);
        std.mem.copy(vk.ImageView, frame_image_views[1..], image_views);

        for (framebuffers, target_image_views) |*framebuffer, *iv| {
            frame_image_views[0] = iv.*;

            const create_info: vk.FramebufferCreateInfo = .{
                .flags = .{},
                .render_pass = render_pass.vk_ref,
                .attachment_count = @intCast(frame_image_views.len),
                .p_attachments = @ptrCast(frame_image_views.ptr),
                .width = width,
                .height = height,
                .layers = 1,
            };

            framebuffer.vk_ref = vkfn.d.createFramebuffer(vkctxt.device, &create_info, null) catch |err| {
                printVulkanError("Can't create framebuffer from swapchain", err);
                return undefined;
            };
            framebuffer.render_pass = render_pass;
        }

        return framebuffers;
    }

    pub fn createFromSwapchain(render_pass: *RenderPass, swapchain: *Swapchain, image_views: []vk.ImageView) []Framebuffer {
        return createFromParams(
            render_pass,
            swapchain.image_count,
            swapchain.image_extent.width,
            swapchain.image_extent.height,
            swapchain.image_views,
            image_views,
        );
    }

    pub fn createFromViewportTexture(render_pass: *RenderPass, viewport_texture: *ViewportTexture, image_views: []vk.ImageView) []Framebuffer {
        var target_image_views: []vk.ImageView = vkctxt.allocator.alloc(vk.ImageView, viewport_texture.textures.len) catch unreachable;
        defer vkctxt.allocator.free(target_image_views);

        for (target_image_views, viewport_texture.textures) |*iv, *tex|
            iv.* = tex.view;

        return createFromParams(
            render_pass,
            viewport_texture.textures.len,
            viewport_texture.extent.width,
            viewport_texture.extent.height,
            target_image_views,
            image_views,
        );
    }

    pub fn destroy(self: *Framebuffer) void {
        vkfn.d.destroyFramebuffer(vkctxt.device, self.vk_ref, null);
    }

    pub fn destroyFramebuffers(framebuffers: []Framebuffer) void {
        for (framebuffers) |*fb|
            fb.destroy();
        vkctxt.allocator.free(framebuffers);
    }

    pub fn recreateFramebuffers(framebuffers: *[]Framebuffer, target: anytype, image_views: []ImageView) void {
        const rp: *RenderPass = framebuffers.*[0].render_pass;
        destroyFramebuffers(framebuffers.*);
        framebuffers.* = create(rp, target, image_views);
    }
};
