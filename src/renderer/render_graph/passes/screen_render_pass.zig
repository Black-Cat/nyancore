const std = @import("std");
const vk = @import("../../../vk.zig");
const shader_util = @import("../../../shaders/shader_util.zig");
usingnamespace @import("../../../vulkan_wrapper/vulkan_wrapper.zig");

const RGPass = @import("../render_graph_pass.zig").RGPass;
const ViewportTexture = @import("../resources/viewport_texture.zig").ViewportTexture;

pub const ScreenRenderPass = struct {
    const VertPushConstBlock = struct {
        aspect_ratio: [4]f32,
    };

    rg_pass: RGPass,
    target: *ViewportTexture,
    allocator: *std.mem.Allocator,

    render_pass: vk.RenderPass,
    framebuffers: []vk.Framebuffer,

    pipeline_cache: vk.PipelineCache,
    pipeline_layout: vk.PipelineLayout,
    pipeline: vk.Pipeline,

    vert_shader: vk.ShaderModule,
    frag_shader: vk.ShaderModule,

    descriptor_sets: *[]vk.DescriptorSet,
    descriptor_set_layout: *vk.DescriptorSetLayout,

    pub fn init(
        self: *ScreenRenderPass,
        name: []const u8,
        allocator: *std.mem.Allocator,
        target: *ViewportTexture,
        descriptor_sets: *[]vk.DescriptorSet,
        descriptor_set_layout: *vk.DescriptorSetLayout,
    ) void {
        self.allocator = allocator;
        self.descriptor_sets = descriptor_sets;
        self.target = target;
        self.descriptor_set_layout = descriptor_set_layout;

        self.rg_pass.init(name, allocator, passInit, passDeinit, passRender);
        target.rg_resource.registerOnChangeCallback(&self.rg_pass, reinitFramebuffer);

        self.framebuffers = allocator.alloc(vk.Framebuffer, target.textures.len) catch unreachable;
    }

    pub fn deinit(self: *ScreenRenderPass) void {
        self.allocator.free(self.framebuffers);
    }

    fn passInit(render_pass: *RGPass) void {
        const self: *ScreenRenderPass = @fieldParentPtr(ScreenRenderPass, "rg_pass", render_pass);

        const vert_code = @embedFile("screen_render_pass.vert");
        const frag_code = @embedFile("screen_render_pass.frag");
        self.vert_shader = shader_util.loadShader(vert_code, .vertex);
        self.frag_shader = shader_util.loadShader(frag_code, .fragment);

        const color_attachment: vk.AttachmentDescription = .{
            .format = self.target.image_format,
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .@"undefined",
            .final_layout = .present_src_khr,
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

        self.render_pass = vkd.createRenderPass(vkc.device, render_pass_create_info, null) catch |err| {
            printVulkanError("Can't create render pass for screen render pass", err, vkc.allocator);
            return;
        };

        self.createFramebuffers();
        self.createPipelineCache();
        self.createPipelineLayout();
        self.createPipeline();
    }

    fn passDeinit(render_pass: *RGPass) void {
        const self: *ScreenRenderPass = @fieldParentPtr(ScreenRenderPass, "rg_pass", render_pass);
        vkd.destroyRenderPass(vkc.device, self.render_pass, null);

        vkd.destroyPipeline(vkc.device, self.pipeline, null);
        vkd.destroyPipelineLayout(vkc.device, self.pipeline_layout, null);
        vkd.destroyPipelineCache(vkc.device, self.pipeline_cache, null);

        self.destroyFramebuffers();

        vkd.destroyShaderModule(vkc.device, self.vert_shader, null);
        vkd.destroyShaderModule(vkc.device, self.frag_shader, null);
    }

    fn passRender(render_pass: *RGPass, command_buffer: vk.CommandBuffer, image_index: u32) void {
        const self: *ScreenRenderPass = @fieldParentPtr(ScreenRenderPass, "rg_pass", render_pass);

        const clear_color: vk.ClearValue = .{ .color = .{ .float_32 = [_]f32{ 0.6, 0.3, 0.6, 1.0 } } };
        const render_pass_info: vk.RenderPassBeginInfo = .{
            .render_pass = self.render_pass,
            .framebuffer = self.framebuffers[image_index],
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{
                    .width = self.target.width,
                    .height = self.target.height,
                },
            },
            .clear_value_count = 1,
            .p_clear_values = @ptrCast([*]const vk.ClearValue, &clear_color),
        };

        vkd.cmdBeginRenderPass(command_buffer, render_pass_info, .@"inline");
        defer vkd.cmdEndRenderPass(command_buffer);

        const descriptor_set: [*]const vk.DescriptorSet = @ptrCast([*]const vk.DescriptorSet, &self.descriptor_sets.*[image_index]);
        vkd.vkCmdBindDescriptorSets(command_buffer, .graphics, self.pipeline_layout, 0, 1, descriptor_set, 0, undefined);
        vkd.cmdBindPipeline(command_buffer, .graphics, self.pipeline);

        const viewport_info: vk.Viewport = .{
            .width = @intToFloat(f32, self.target.width),
            .height = @intToFloat(f32, self.target.height),
            .min_depth = 0.0,
            .max_depth = 1.0,
            .x = 0,
            .y = 0,
        };

        vkd.cmdSetViewport(command_buffer, 0, 1, @ptrCast([*]const vk.Viewport, &viewport_info));

        const scissor_rect: vk.Rect2D = .{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{
                .width = self.target.width,
                .height = self.target.height,
            },
        };

        vkd.cmdSetScissor(command_buffer, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor_rect));

        var push_const_block: VertPushConstBlock = .{
            .aspect_ratio = [4]f32{ 1.0, 1.0, 0.0, 0.0 },
        };

        if (self.target.width > self.target.height) {
            push_const_block.aspect_ratio[0] = viewport_info.width / viewport_info.height;
        } else {
            push_const_block.aspect_ratio[1] = viewport_info.height / viewport_info.width;
        }

        vkd.cmdPushConstants(command_buffer, self.pipeline_layout, .{ .vertex_bit = true }, 0, @sizeOf(VertPushConstBlock), @ptrCast([*]const VertPushConstBlock, &push_const_block));

        vkd.cmdDraw(command_buffer, 3, 1, 0, 0);
    }

    fn createFramebuffers(self: *ScreenRenderPass) void {
        for (self.framebuffers) |*framebuffer, i| {
            const create_info: vk.FramebufferCreateInfo = .{
                .flags = .{},
                .render_pass = self.render_pass,
                .attachment_count = 1,
                .p_attachments = @ptrCast([*]const vk.ImageView, &self.target.textures[i].view),
                .width = self.target.width,
                .height = self.target.height,
                .layers = 1,
            };

            framebuffer.* = vkd.createFramebuffer(vkc.device, create_info, null) catch |err| {
                printVulkanError("Can't create framebuffer for screen render pass", err, vkc.allocator);
                return;
            };
        }
    }

    fn destroyFramebuffers(self: *ScreenRenderPass) void {
        for (self.framebuffers) |f|
            vkd.destroyFramebuffer(vkc.device, f, null);
    }

    fn reinitFramebuffer(render_pass: *RGPass) void {
        const self: *ScreenRenderPass = @fieldParentPtr(ScreenRenderPass, "rg_pass", render_pass);

        self.destroyFramebuffers();
        self.createFramebuffers();
    }

    fn createPipelineCache(self: *ScreenRenderPass) void {
        const pipeline_cache_create_info: vk.PipelineCacheCreateInfo = .{
            .flags = .{},
            .initial_data_size = 0,
            .p_initial_data = undefined,
        };

        self.pipeline_cache = vkd.createPipelineCache(vkc.device, pipeline_cache_create_info, null) catch |err| {
            printVulkanError("Can't create pipeline cache", err, vkc.allocator);
            return;
        };
    }

    fn createPipelineLayout(self: *ScreenRenderPass) void {
        const push_constant_range: vk.PushConstantRange = .{
            .stage_flags = .{ .vertex_bit = true },
            .offset = 0,
            .size = @sizeOf(VertPushConstBlock),
        };

        const pipeline_layout_create_info: vk.PipelineLayoutCreateInfo = .{
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast([*]const vk.DescriptorSetLayout, self.descriptor_set_layout),
            .push_constant_range_count = 1,
            .p_push_constant_ranges = @ptrCast([*]const vk.PushConstantRange, &push_constant_range),
            .flags = .{},
        };

        self.pipeline_layout = vkd.createPipelineLayout(vkc.device, pipeline_layout_create_info, null) catch |err| {
            printVulkanError("Can't create pipeline layout", err, vkc.allocator);
            return;
        };
    }

    fn createPipeline(self: *ScreenRenderPass) void {
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
            .blend_enable = vk.TRUE,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
            .src_color_blend_factor = .src_alpha,
            .dst_color_blend_factor = .one_minus_src_alpha,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one_minus_src_alpha,
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

        const ui_vert_shader_stage: vk.PipelineShaderStageCreateInfo = .{
            .stage = .{ .vertex_bit = true },
            .module = self.vert_shader,
            .p_name = "main",
            .flags = .{},
            .p_specialization_info = null,
        };

        const ui_frag_shader_stage: vk.PipelineShaderStageCreateInfo = .{
            .stage = .{ .fragment_bit = true },
            .module = self.frag_shader,
            .p_name = "main",
            .flags = .{},
            .p_specialization_info = null,
        };

        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{ ui_vert_shader_stage, ui_frag_shader_stage };

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

            .stage_count = 2,
            .p_stages = @ptrCast([*]const vk.PipelineShaderStageCreateInfo, &shader_stages),

            .p_tessellation_state = null,
            .subpass = 0,
        };

        _ = vkd.createGraphicsPipelines(
            vkc.device,
            self.pipeline_cache,
            1,
            @ptrCast([*]const vk.GraphicsPipelineCreateInfo, &pipeline_create_info),
            null,
            @ptrCast([*]vk.Pipeline, &self.pipeline),
        ) catch |err| {
            printVulkanError("Can't create graphics pipeline for screen render pass", err, vkc.allocator);
            return;
        };
    }
};
