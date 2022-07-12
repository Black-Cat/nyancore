const std = @import("std");

const rg = @import("../render_graph.zig");
const vk = @import("../../../vk.zig");

const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../../../vulkan_wrapper/vulkan_functions.zig");

const RGPass = @import("../render_graph_pass.zig").RGPass;
const RGResource = @import("../render_graph_resource.zig").RGResource;
const Swapchain = @import("../../../vulkan_wrapper/swapchain.zig").Swapchain;
const ViewportTexture = @import("../resources/viewport_texture.zig").ViewportTexture;
const CommandBuffer = @import("../../../vulkan_wrapper/command_buffer.zig").CommandBuffer;
const RenderPass = @import("../../../vulkan_wrapper/render_pass.zig").RenderPass;
const ShaderModule = @import("../../../vulkan_wrapper/shader_module.zig").ShaderModule;

const printVulkanError = @import("../../../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

pub fn ScreenRenderPass(comptime TargetType: type) type {
    return struct {
        const VertPushConstBlock = struct {
            aspect_ratio: [4]f32,
        };

        const SelfType = ScreenRenderPass(TargetType);

        rg_pass: RGPass,

        render_pass: RenderPass,
        target: *TargetType,

        pipeline_cache: vk.PipelineCache,
        pipeline_layout: vk.PipelineLayout,
        pipeline: vk.Pipeline,

        vert_shader: ShaderModule,

        frag_shader: *vk.ShaderModule,
        frag_push_const_size: usize,
        frag_push_const_block: *const anyopaque,

        custom_scissors: ?*vk.Rect2D,

        // Accepts *ViewportTexture or *Swapchain as target
        pub fn init(
            self: *SelfType,
            comptime name: []const u8,
            target: *TargetType,
            frag_shader: *vk.ShaderModule,
            frag_push_const_size: usize,
            frag_push_const_block: *const anyopaque,
        ) void {
            self.frag_shader = frag_shader;
            self.frag_push_const_size = frag_push_const_size;
            self.frag_push_const_block = frag_push_const_block;

            const res: *RGResource = rg.global_render_graph.getResource(target);

            self.rg_pass.init(name, rg.global_render_graph.allocator, passInit, passDeinit, passRender);
            self.rg_pass.appendWriteResource(res);

            self.target = target;

            self.custom_scissors = null;

            self.rg_pass.pipeline_start = .{ .fragment_shader_bit = true };
            self.rg_pass.pipeline_end = .{ .color_attachment_output_bit = true };
        }

        pub fn deinit(self: *SelfType) void {
            _ = self;
        }

        fn passInit(rg_pass: *RGPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", rg_pass);

            const vert_code = @embedFile("screen_render_pass.vert");
            self.vert_shader = ShaderModule.load(vert_code, .vertex);

            var color_attachment: [1]vk.AttachmentDescription = .{.{
                .format = self.target.image_format,
                .samples = .{ .@"1_bit" = true },
                .load_op = self.rg_pass.load_op,
                .store_op = .store,
                .stencil_load_op = .dont_care,
                .stencil_store_op = .dont_care,
                .initial_layout = self.rg_pass.initial_layout,
                .final_layout = self.rg_pass.final_layout,
                .flags = .{},
            }};

            self.render_pass.init(self.target, color_attachment[0..]);

            self.createPipelineCache();
            self.createPipelineLayout();
            self.createPipeline();
        }

        fn passDeinit(render_pass: *RGPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", render_pass);
            self.render_pass.destroy();

            vkfn.d.destroyPipeline(vkctxt.device, self.pipeline, null);
            vkfn.d.destroyPipelineLayout(vkctxt.device, self.pipeline_layout, null);
            vkfn.d.destroyPipelineCache(vkctxt.device, self.pipeline_cache, null);

            self.vert_shader.destroy();
        }

        fn passRender(render_pass: *RGPass, command_buffer: *CommandBuffer, frame_index: u32) void {
            _ = frame_index;

            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", render_pass);

            const clear_color: vk.ClearValue = .{ .color = .{ .float_32 = [_]f32{ 0.6, 0.3, 0.6, 1.0 } } };
            const render_pass_info: vk.RenderPassBeginInfo = .{
                .render_pass = self.render_pass.vk_ref,
                .framebuffer = self.render_pass.getCurrentFramebuffer().vk_ref,
                .render_area = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = self.target.extent,
                },
                .clear_value_count = 1,
                .p_clear_values = @ptrCast([*]const vk.ClearValue, &clear_color),
            };

            vkfn.d.cmdBeginRenderPass(command_buffer.vk_ref, render_pass_info, .@"inline");
            defer vkfn.d.cmdEndRenderPass(command_buffer.vk_ref);

            vkfn.d.cmdBindPipeline(command_buffer.vk_ref, .graphics, self.pipeline);

            const viewport_info: vk.Viewport = .{
                .width = @intToFloat(f32, self.target.extent.width),
                .height = @intToFloat(f32, self.target.extent.height),
                .min_depth = 0.0,
                .max_depth = 1.0,
                .x = 0,
                .y = 0,
            };

            vkfn.d.cmdSetViewport(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Viewport, &viewport_info));

            var scissor_rect: vk.Rect2D = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = .{
                    .width = self.target.extent.width,
                    .height = self.target.extent.height,
                },
            };

            const scissor_rect_ptr: *vk.Rect2D = if (self.custom_scissors) |custom_scissors| custom_scissors else &scissor_rect;
            vkfn.d.cmdSetScissor(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Rect2D, scissor_rect_ptr));

            var push_const_block: VertPushConstBlock = .{
                .aspect_ratio = [4]f32{ 1.0, 1.0, 0.0, 0.0 },
            };

            if (self.target.extent.width > self.target.extent.height) {
                push_const_block.aspect_ratio[0] = viewport_info.width / viewport_info.height;
            } else {
                push_const_block.aspect_ratio[1] = viewport_info.height / viewport_info.width;
            }

            vkfn.d.cmdPushConstants(
                command_buffer.vk_ref,
                self.pipeline_layout,
                .{ .vertex_bit = true },
                0,
                @sizeOf(VertPushConstBlock),
                @ptrCast([*]const VertPushConstBlock, &push_const_block),
            );

            vkfn.d.cmdPushConstants(
                command_buffer.vk_ref,
                self.pipeline_layout,
                .{ .fragment_bit = true },
                @sizeOf(VertPushConstBlock),
                @intCast(u32, self.frag_push_const_size),
                self.frag_push_const_block,
            );

            vkfn.d.cmdDraw(command_buffer.vk_ref, 3, 1, 0, 0);
        }

        fn createPipelineCache(self: *SelfType) void {
            const pipeline_cache_create_info: vk.PipelineCacheCreateInfo = .{
                .flags = .{},
                .initial_data_size = 0,
                .p_initial_data = undefined,
            };

            self.pipeline_cache = vkfn.d.createPipelineCache(vkctxt.device, pipeline_cache_create_info, null) catch |err| {
                printVulkanError("Can't create pipeline cache", err);
                return;
            };
        }

        fn createPipelineLayout(self: *SelfType) void {
            const push_constant_range: [2]vk.PushConstantRange = [_]vk.PushConstantRange{
                .{
                    .stage_flags = .{ .vertex_bit = true },
                    .offset = 0,
                    .size = @sizeOf(VertPushConstBlock),
                },
                .{
                    .stage_flags = .{ .fragment_bit = true },
                    .offset = @sizeOf(VertPushConstBlock),
                    .size = @intCast(u32, self.frag_push_const_size),
                },
            };

            const pipeline_layout_create_info: vk.PipelineLayoutCreateInfo = .{
                .set_layout_count = 0,
                .p_set_layouts = undefined,
                .push_constant_range_count = 2,
                .p_push_constant_ranges = @ptrCast([*]const vk.PushConstantRange, &push_constant_range),
                .flags = .{},
            };

            self.pipeline_layout = vkfn.d.createPipelineLayout(vkctxt.device, pipeline_layout_create_info, null) catch |err| {
                printVulkanError("Can't create pipeline layout", err);
                return;
            };
        }

        fn recreatePipeline(self: *SelfType) void {
            vkfn.d.destroyPipeline(vkctxt.device, self.pipeline, null);
            self.createPipeline();
        }

        pub fn recreatePipelineOnShaderChange(pass: *RGPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", pass);
            self.recreatePipeline();
        }

        fn createPipeline(self: *SelfType) void {
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

            const ui_vert_shader_stage: vk.PipelineShaderStageCreateInfo = .{
                .stage = .{ .vertex_bit = true },
                .module = self.vert_shader.vk_ref,
                .p_name = "main",
                .flags = .{},
                .p_specialization_info = null,
            };

            const ui_frag_shader_stage: vk.PipelineShaderStageCreateInfo = .{
                .stage = .{ .fragment_bit = true },
                .module = self.frag_shader.*,
                .p_name = "main",
                .flags = .{},
                .p_specialization_info = null,
            };

            const shader_stages = [_]vk.PipelineShaderStageCreateInfo{ ui_vert_shader_stage, ui_frag_shader_stage };

            const pipeline_create_info: vk.GraphicsPipelineCreateInfo = .{
                .layout = self.pipeline_layout,
                .render_pass = self.render_pass.vk_ref,
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

            _ = vkfn.d.createGraphicsPipelines(
                vkctxt.device,
                self.pipeline_cache,
                1,
                @ptrCast([*]const vk.GraphicsPipelineCreateInfo, &pipeline_create_info),
                null,
                @ptrCast([*]vk.Pipeline, &self.pipeline),
            ) catch |err| {
                printVulkanError("Can't create graphics pipeline for screen render pass", err);
                return;
            };
        }
    };
}
