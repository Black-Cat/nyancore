const vk = @import("../vk.zig");
const std = @import("std");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");
const rg = @import("../renderer/render_graph/render_graph.zig");

const printVulkanError = @import("../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Swapchain = @import("swapchain.zig").Swapchain;

pub const RenderPass = struct {
    vk_ref: vk.RenderPass,

    framebuffers: []Framebuffer,
    framebuffer_index: *u32,

    pub fn create(target: anytype, attachments: []vk.AttachmentDescription) RenderPass {
        var res: RenderPass = undefined;

        res.vk_ref = createVulkanRenderPass(attachments);
        res.framebuffers = Framebuffer.create(&res, target);
        res.framebuffer_index = if (@TypeOf(target) == *Swapchain) &rg.global_render_graph.image_index else &rg.global_render_graph.frame_index;

        return res;
    }

    pub fn destroy(self: *RenderPass) void {
        destroyFramebuffers(self.framebuffers);

        vkfn.d.destroyRenderPass(vkctxt.device, self.vk_ref, null);
    }

    pub fn getCurrentFramebuffer(self: *RenderPass) *Framebuffer {
        return &self.framebuffers[@intCast(usize, self.framebuffer_index.*)];
    }

    pub fn recreateFramebuffers(self: *RenderPass, target: anytype) void {
        destroyFramebuffers(self.framebuffers);
        self.framebuffers = Framebuffer.create(self, target);
    }

    fn destroyFramebuffers(framebuffers: []Framebuffer) void {
        for (framebuffers) |*fb|
            fb.destroy();
        vkctxt.allocator.free(framebuffers);
    }

    fn createVulkanRenderPass(attachments: []vk.AttachmentDescription) vk.RenderPass {
        var attachment_references: []vk.AttachmentReference = vkctxt.allocator.alloc(vk.AttachmentReference, attachments.len) catch unreachable;
        defer vkctxt.allocator.free(attachment_references);

        for (attachment_references) |*ar, ind|
            ar.* = .{
                .attachment = @intCast(u32, ind),
                .layout = .color_attachment_optimal,
            };

        const subpass: vk.SubpassDescription = .{
            .pipeline_bind_point = .graphics,
            .color_attachment_count = @intCast(u32, attachment_references.len),
            .p_color_attachments = @ptrCast([*]const vk.AttachmentReference, attachment_references.ptr),

            .flags = .{},
            .input_attachment_count = 0,
            .p_input_attachments = undefined,
            .p_resolve_attachments = null,
            .p_depth_stencil_attachment = null,
            .preserve_attachment_count = 0,
            .p_preserve_attachments = undefined,
        };

        const dependency: vk.SubpassDependency = .{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .color_attachment_output_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .color_attachment_output_bit = true },
            .dst_access_mask = .{ .color_attachment_read_bit = true, .color_attachment_write_bit = true },
            .dependency_flags = .{},
        };

        const render_pass_create_info: vk.RenderPassCreateInfo = .{
            .attachment_count = @intCast(u32, attachments.len),
            .p_attachments = @ptrCast([*]const vk.AttachmentDescription, attachments.ptr),
            .subpass_count = 1,
            .p_subpasses = @ptrCast([*]const vk.SubpassDescription, &subpass),
            .dependency_count = 1,
            .p_dependencies = @ptrCast([*]const vk.SubpassDependency, &dependency),
            .flags = .{},
        };

        return vkfn.d.createRenderPass(vkctxt.device, render_pass_create_info, null) catch |err| {
            printVulkanError("Can't create render pass", err);
            unreachable;
        };
    }
};
