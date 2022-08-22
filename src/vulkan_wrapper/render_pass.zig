const vk = @import("../vk.zig");
const std = @import("std");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");
const rg = @import("../renderer/render_graph/render_graph.zig");

const printVulkanError = @import("../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const Framebuffer = @import("framebuffer.zig").Framebuffer;
const Swapchain = @import("swapchain.zig").Swapchain;
const ImageView = @import("image_view.zig").ImageView;

pub const RenderPass = struct {
    vk_ref: vk.RenderPass,

    framebuffers: []Framebuffer,
    framebuffer_index: *u32,

    target_render_passes: *std.ArrayList(*RenderPass),
    target_recreated_callback: fn (self: *RenderPass) void,

    // Attachments should go in order: color, depth
    pub fn init(self: *RenderPass, target: anytype, image_views: []ImageView, attachments: []vk.AttachmentDescription) void {
        self.vk_ref = createVulkanRenderPass(attachments);
        self.framebuffers = Framebuffer.create(self, target, image_views);
        self.framebuffer_index = if (@TypeOf(target) == *Swapchain) &rg.global_render_graph.image_index else &rg.global_render_graph.frame_index;

        self.target_recreated_callback = targetRecreatedCallback;
        self.target_render_passes = &target.render_passes;
        target.render_passes.append(self) catch unreachable;
    }

    pub fn destroy(self: *RenderPass) void {
        for (self.target_render_passes.items) |rp, ind| {
            if (rp == self) {
                _ = self.target_render_passes.swapRemove(ind);
                break;
            }
        }

        Framebuffer.destroyFramebuffers(self.framebuffers);
        vkfn.d.destroyRenderPass(vkctxt.device, self.vk_ref, null);
    }

    pub fn recreateFramebuffers(self: *RenderPass, target: anytype, image_views: []ImageView) void {
        Framebuffer.destroyFramebuffers(self.framebuffers);

        self.framebuffers = Framebuffer.create(self, target, image_views);
        self.framebuffer_index = if (@TypeOf(target) == *Swapchain) &rg.global_render_graph.image_index else &rg.global_render_graph.frame_index;
    }

    pub fn getCurrentFramebuffer(self: *RenderPass) *Framebuffer {
        return &self.framebuffers[@intCast(usize, self.framebuffer_index.*)];
    }

    fn targetRecreatedCallback(self: *RenderPass) void {
        _ = self;
    }

    fn createVulkanRenderPass(attachments: []vk.AttachmentDescription) vk.RenderPass {
        var attachment_references: []vk.AttachmentReference = vkctxt.allocator.alloc(vk.AttachmentReference, attachments.len) catch unreachable;
        defer vkctxt.allocator.free(attachment_references);

        for (attachment_references) |*ar, ind|
            ar.* = .{
                .attachment = @intCast(u32, ind),
                .layout = .color_attachment_optimal,
            };

        const has_depth_attachment: bool = attachments.len > 0 and attachments[attachments.len - 1].final_layout == .depth_stencil_attachment_optimal;
        if (has_depth_attachment)
            attachment_references[attachment_references.len - 1].layout = .depth_stencil_attachment_optimal;

        var color_attachment_count: u32 = @intCast(u32, attachment_references.len);
        if (has_depth_attachment)
            color_attachment_count -= 1;

        const depth_attachment_ptr: ?*const vk.AttachmentReference = if (has_depth_attachment) @ptrCast(
            *const vk.AttachmentReference,
            &attachment_references[attachment_references.len - 1],
        ) else null;

        const subpass: vk.SubpassDescription = .{
            .pipeline_bind_point = .graphics,
            .color_attachment_count = color_attachment_count,
            .p_color_attachments = @ptrCast([*]const vk.AttachmentReference, attachment_references.ptr),
            .p_depth_stencil_attachment = depth_attachment_ptr,

            .flags = .{},
            .input_attachment_count = 0,
            .p_input_attachments = undefined,
            .p_resolve_attachments = null,
            .preserve_attachment_count = 0,
            .p_preserve_attachments = undefined,
        };

        const color_dependency: vk.SubpassDependency = .{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .color_attachment_output_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .color_attachment_output_bit = true },
            .dst_access_mask = .{ .color_attachment_write_bit = true },
            .dependency_flags = .{},
        };

        const depth_dependency: vk.SubpassDependency = .{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .dst_access_mask = .{ .depth_stencil_attachment_write_bit = true },
            .dependency_flags = .{},
        };

        const dependencies: [2]vk.SubpassDependency = .{ color_dependency, depth_dependency };

        const render_pass_create_info: vk.RenderPassCreateInfo = .{
            .attachment_count = @intCast(u32, attachments.len),
            .p_attachments = @ptrCast([*]const vk.AttachmentDescription, attachments.ptr),
            .subpass_count = 1,
            .p_subpasses = @ptrCast([*]const vk.SubpassDescription, &subpass),
            .dependency_count = if (has_depth_attachment) 2 else 1,
            .p_dependencies = @ptrCast([*]const vk.SubpassDependency, &dependencies),
            .flags = .{},
        };

        return vkfn.d.createRenderPass(vkctxt.device, render_pass_create_info, null) catch |err| {
            printVulkanError("Can't create render pass", err);
            unreachable;
        };
    }
};
