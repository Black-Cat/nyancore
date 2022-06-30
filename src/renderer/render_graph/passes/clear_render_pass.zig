const std = @import("std");

const rg = @import("../render_graph.zig");
const shader_util = @import("../../../shaders/shader_util.zig");
const vk = @import("../../../vk.zig");
const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");

const RGPass = @import("../render_graph_pass.zig").RGPass;
const Swapchain = @import("../../../vulkan_wrapper/swapchain.zig").Swapchain;
const CommandBuffer = @import("../../../vulkan_wrapper/command_buffer.zig").CommandBuffer;

pub const ClearRenderPass = struct {
    rg_pass: RGPass,
    allocator: std.mem.Allocator,

    render_pass: vk.RenderPass,
    framebuffers: []vk.Framebuffer,

    target_image_format: vk.Format,
    target_width: u32,
    target_height: u32,

    pipeline_cache: vk.PipelineCache,
    pipeline_layout: vk.PipelineLayout,
    pipeline: vk.Pipeline,

    clear_color: vk.ClearValue,

    pub fn init(
        self: *ClearRenderPass,
        comptime name: []const u8,
        allocator: std.mem.Allocator,
        target: *Swapchain,
        color: vk.ClearValue,
    ) void {
        self.target_image_format = target.image_format;
        self.target_width = target.image_extent.width;
        self.target_height = target.image_extent.height;
        self.framebuffers = target.framebuffers;

        self.allocator = allocator;
        self.clear_color = color;

        self.rg_pass.init(name, allocator, passInit, passDeinit, passRender);
        self.rg_pass.appendWriteResource(&target.rg_resource);

        self.rg_pass.pipeline_start = .{ .draw_indirect_bit = true };
        self.rg_pass.pipeline_end = .{ .color_attachment_output_bit = true };
    }

    pub fn deinit(self: *ClearRenderPass) void {
        _ = self;
    }

    fn passInit(render_pass: *RGPass) void {
        const self: *ClearRenderPass = @fieldParentPtr(ClearRenderPass, "rg_pass", render_pass);

        const color_attachment: vk.AttachmentDescription = .{
            .format = self.target_image_format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = self.rg_pass.initial_layout,
            .final_layout = self.rg_pass.final_layout,
            .flags = .{},
        };

        const color_attachment_ref: vk.AttachmentReference = .{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        };

        const subpass: vk.SubpassDescription = .{
            .pipeline_bind_point = .graphics,
            .color_attachment_count = 1,
            .p_color_attachments = @ptrCast([*]const vk.AttachmentReference, &color_attachment_ref),

            .flags = .{},
            .input_attachment_count = 0,
            .p_input_attachments = undefined,
            .p_resolve_attachments = undefined,
            .p_depth_stencil_attachment = undefined,
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
            .attachment_count = 1,
            .p_attachments = @ptrCast([*]const vk.AttachmentDescription, &color_attachment),
            .subpass_count = 1,
            .p_subpasses = @ptrCast([*]const vk.SubpassDescription, &subpass),
            .dependency_count = 1,
            .p_dependencies = @ptrCast([*]const vk.SubpassDependency, &dependency),
            .flags = .{},
        };

        self.render_pass = vkctxt.vkd.createRenderPass(vkctxt.vkc.device, render_pass_create_info, null) catch |err| {
            vkctxt.printVulkanError("Can't create render pass for screen render pass", err, vkctxt.vkc.allocator);
            return;
        };

        self.createPipelineCache();
        self.createPipelineLayout();
        self.createPipeline();
    }

    fn passDeinit(render_pass: *RGPass) void {
        const self: *ClearRenderPass = @fieldParentPtr(ClearRenderPass, "rg_pass", render_pass);

        vkctxt.vkd.destroyRenderPass(vkctxt.vkc.device, self.render_pass, null);

        vkctxt.vkd.destroyPipeline(vkctxt.vkc.device, self.pipeline, null);
        vkctxt.vkd.destroyPipelineLayout(vkctxt.vkc.device, self.pipeline_layout, null);
        vkctxt.vkd.destroyPipelineCache(vkctxt.vkc.device, self.pipeline_cache, null);
    }

    fn passRender(render_pass: *RGPass, command_buffer: *CommandBuffer, frame_index: u32) void {
        _ = frame_index;

        const self: *ClearRenderPass = @fieldParentPtr(ClearRenderPass, "rg_pass", render_pass);

        const render_pass_info: vk.RenderPassBeginInfo = .{
            .render_pass = self.render_pass,
            .framebuffer = self.framebuffers[rg.global_render_graph.image_index],
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{
                    .width = self.target_width,
                    .height = self.target_height,
                },
            },
            .clear_value_count = 1,
            .p_clear_values = @ptrCast([*]const vk.ClearValue, &self.clear_color),
        };

        vkctxt.vkd.cmdBeginRenderPass(command_buffer.vk_ref, render_pass_info, .@"inline");
        defer vkctxt.vkd.cmdEndRenderPass(command_buffer.vk_ref);

        const viewport_info: vk.Viewport = .{
            .width = @intToFloat(f32, self.target_width),
            .height = @intToFloat(f32, self.target_height),
            .min_depth = 0.0,
            .max_depth = 1.0,
            .x = 0,
            .y = 0,
        };
        vkctxt.vkd.cmdSetViewport(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Viewport, &viewport_info));

        var scissor_rect: vk.Rect2D = .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{
                .width = self.target_width,
                .height = self.target_height,
            },
        };
        vkctxt.vkd.cmdSetScissor(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor_rect));
    }

    fn createPipelineCache(self: *ClearRenderPass) void {
        const pipeline_cache_create_info: vk.PipelineCacheCreateInfo = .{
            .flags = .{},
            .initial_data_size = 0,
            .p_initial_data = undefined,
        };

        self.pipeline_cache = vkctxt.vkd.createPipelineCache(vkctxt.vkc.device, pipeline_cache_create_info, null) catch |err| {
            vkctxt.printVulkanError("Can't create pipeline cache", err, vkctxt.vkc.allocator);
            return;
        };
    }

    fn createPipelineLayout(self: *ClearRenderPass) void {
        const pipeline_layout_create_info: vk.PipelineLayoutCreateInfo = .{
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
            .flags = .{},
        };

        self.pipeline_layout = vkctxt.vkd.createPipelineLayout(vkctxt.vkc.device, pipeline_layout_create_info, null) catch |err| {
            vkctxt.printVulkanError("Can't create pipeline layout", err, vkctxt.vkc.allocator);
            return;
        };
    }

    fn createPipeline(self: *ClearRenderPass) void {
        const input_assembly_state: vk.PipelineInputAssemblyStateCreateInfo = .{
            .topology = .triangle_list,
            .flags = .{},
            .primitive_restart_enable = vk.FALSE,
        };

        const rasterization_state: vk.PipelineRasterizationStateCreateInfo = .{
            .polygon_mode = .fill,
            .cull_mode = .{},
            .front_face = .counter_clockwise,
            .flags = .{},
            .depth_clamp_enable = vk.FALSE,
            .line_width = 1.0,

            .rasterizer_discard_enable = vk.FALSE,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
        };

        const blend_attachment_state: vk.PipelineColorBlendAttachmentState = .{
            .blend_enable = vk.FALSE,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
            .src_color_blend_factor = .src_alpha,
            .dst_color_blend_factor = .one_minus_src_alpha,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
        };

        const color_blend_state: vk.PipelineColorBlendStateCreateInfo = .{
            .attachment_count = 1,
            .p_attachments = @ptrCast([*]const vk.PipelineColorBlendAttachmentState, &blend_attachment_state),

            .flags = .{},
            .logic_op_enable = vk.FALSE,
            .logic_op = undefined,
            .blend_constants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        };

        const depth_stencil_state: vk.PipelineDepthStencilStateCreateInfo = .{
            .depth_test_enable = vk.FALSE,
            .depth_write_enable = vk.FALSE,
            .depth_compare_op = .less_or_equal,
            .back = .{
                .compare_op = .always,
                .fail_op = .keep,
                .pass_op = .keep,
                .depth_fail_op = .keep,
                .compare_mask = 0,
                .write_mask = 0,
                .reference = 0,
            },
            .front = .{
                .compare_op = .never,
                .fail_op = .keep,
                .pass_op = .keep,
                .depth_fail_op = .keep,
                .compare_mask = 0,
                .write_mask = 0,
                .reference = 0,
            },

            .depth_bounds_test_enable = vk.FALSE,
            .stencil_test_enable = vk.FALSE,
            .flags = .{},
            .min_depth_bounds = 0.0,
            .max_depth_bounds = 0.0,
        };

        const viewport_state: vk.PipelineViewportStateCreateInfo = .{
            .viewport_count = 1,
            .p_viewports = null,
            .scissor_count = 1,
            .p_scissors = null,
            .flags = .{},
        };

        const multisample_state: vk.PipelineMultisampleStateCreateInfo = .{
            .rasterization_samples = .{ .@"1_bit" = true },
            .flags = .{},

            .sample_shading_enable = vk.FALSE,
            .min_sample_shading = 0,
            .p_sample_mask = undefined,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

        const dynamic_enabled_states = [_]vk.DynamicState{ .viewport, .scissor };
        const dynamic_state: vk.PipelineDynamicStateCreateInfo = .{
            .p_dynamic_states = @ptrCast([*]const vk.DynamicState, &dynamic_enabled_states),
            .dynamic_state_count = 2,
            .flags = .{},
        };

        const vertex_input_state: vk.PipelineVertexInputStateCreateInfo = .{
            .vertex_binding_description_count = 0,
            .p_vertex_binding_descriptions = undefined,
            .vertex_attribute_description_count = 0,
            .p_vertex_attribute_descriptions = undefined,
            .flags = .{},
        };

        const vert_code = @embedFile("clear_render_pass.vert");
        const vert_shader = shader_util.loadShader(vert_code, .vertex);
        defer vkctxt.vkd.destroyShaderModule(vkctxt.vkc.device, vert_shader, null);

        const ui_vert_shader_stage: vk.PipelineShaderStageCreateInfo = .{
            .stage = .{ .vertex_bit = true },
            .module = vert_shader,
            .p_name = "main",
            .flags = .{},
            .p_specialization_info = null,
        };

        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{ui_vert_shader_stage};

        const pipeline_create_info: vk.GraphicsPipelineCreateInfo = .{
            .layout = self.pipeline_layout,
            .render_pass = self.render_pass,
            .flags = .{},
            .base_pipeline_index = -1,
            .base_pipeline_handle = .null_handle,

            .p_input_assembly_state = &input_assembly_state,
            .p_rasterization_state = &rasterization_state,
            .p_color_blend_state = &color_blend_state,
            .p_multisample_state = &multisample_state,
            .p_viewport_state = &viewport_state,
            .p_depth_stencil_state = &depth_stencil_state,
            .p_dynamic_state = &dynamic_state,
            .p_vertex_input_state = &vertex_input_state,

            .stage_count = 1,
            .p_stages = @ptrCast([*]const vk.PipelineShaderStageCreateInfo, &shader_stages),

            .p_tessellation_state = null,
            .subpass = 0,
        };

        _ = vkctxt.vkd.createGraphicsPipelines(
            vkctxt.vkc.device,
            self.pipeline_cache,
            1,
            @ptrCast([*]const vk.GraphicsPipelineCreateInfo, &pipeline_create_info),
            null,
            @ptrCast([*]vk.Pipeline, &self.pipeline),
        ) catch |err| {
            vkctxt.printVulkanError("Can't create graphics pipeline for screen render pass", err, vkctxt.vkc.allocator);
            return;
        };
    }
};
