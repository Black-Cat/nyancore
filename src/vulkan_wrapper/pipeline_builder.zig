const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

const RenderPass = @import("render_pass.zig").RenderPass;
const Pipeline = @import("pipeline.zig").Pipeline;
const PipelineCache = @import("pipeline_cache.zig").PipelineCache;
const PipelineLayout = @import("pipeline_layout.zig").PipelineLayout;
const ShaderModule = @import("shader_module.zig").ShaderModule;

pub const PipelineBuilder = struct {
    shader_stages: []const vk.PipelineShaderStageCreateInfo,
    vertex_input_state: vk.PipelineVertexInputStateCreateInfo,
    input_assembly_state: vk.PipelineInputAssemblyStateCreateInfo,
    rasterization_state: vk.PipelineRasterizationStateCreateInfo,
    color_blend_attachment: vk.PipelineColorBlendAttachmentState,
    color_blend_state: vk.PipelineColorBlendStateCreateInfo,
    multisample_state: vk.PipelineMultisampleStateCreateInfo,
    depth_stencil_state: vk.PipelineDepthStencilStateCreateInfo,
    viewport_state: vk.PipelineViewportStateCreateInfo,

    pipeline_cache: *PipelineCache,
    pipeline_layout: *PipelineLayout,

    pub fn build(self: *PipelineBuilder, render_pass: *RenderPass) Pipeline {
        const dynamic_enabled_states = [_]vk.DynamicState{ .viewport, .scissor };
        const dynamic_state: vk.PipelineDynamicStateCreateInfo = .{
            .p_dynamic_states = @ptrCast([*]const vk.DynamicState, &dynamic_enabled_states),
            .dynamic_state_count = 2,
            .flags = .{},
        };

        const pipeline_create_info: vk.GraphicsPipelineCreateInfo = .{
            .layout = self.pipeline_layout.vk_ref,
            .render_pass = render_pass.vk_ref,
            .flags = .{},
            .base_pipeline_index = -1,
            .base_pipeline_handle = .null_handle,

            .p_input_assembly_state = &self.input_assembly_state,
            .p_rasterization_state = &self.rasterization_state,
            .p_color_blend_state = &self.color_blend_state,
            .p_multisample_state = &self.multisample_state,
            .p_viewport_state = &self.viewport_state,
            .p_depth_stencil_state = &self.depth_stencil_state,
            .p_dynamic_state = &dynamic_state,
            .p_vertex_input_state = &self.vertex_input_state,

            .stage_count = @intCast(u32, self.shader_stages.len),
            .p_stages = @ptrCast([*]const vk.PipelineShaderStageCreateInfo, self.shader_stages.ptr),

            .p_tessellation_state = null,
            .subpass = 0,
        };

        var pipeline: Pipeline = undefined;
        _ = vkfn.d.createGraphicsPipelines(
            vkctxt.device,
            self.pipeline_cache.vk_ref,
            1,
            @ptrCast([*]const vk.GraphicsPipelineCreateInfo, &pipeline_create_info),
            null,
            @ptrCast([*]vk.Pipeline, &pipeline.vk_ref),
        ) catch |err| {
            printVulkanError("Can't create graphics pipeline", err);
        };

        return pipeline;
    }

    pub fn buildShaderStageCreateInfo(stage: vk.ShaderStageFlags, shader_module: *const ShaderModule) vk.PipelineShaderStageCreateInfo {
        return .{
            .stage = stage,
            .module = shader_module.vk_ref,
            .p_name = "main",
            .flags = .{},
            .p_specialization_info = null,
        };
    }

    pub fn buildVertexInputStateCreateInfo(
        bindings: []const vk.VertexInputBindingDescription,
        attributes: []const vk.VertexInputAttributeDescription,
    ) vk.PipelineVertexInputStateCreateInfo {
        return .{
            .vertex_binding_description_count = @intCast(u32, bindings.len),
            .p_vertex_binding_descriptions = @ptrCast([*]const vk.VertexInputBindingDescription, bindings.ptr),
            .vertex_attribute_description_count = @intCast(u32, attributes.len),
            .p_vertex_attribute_descriptions = @ptrCast([*]const vk.VertexInputAttributeDescription, attributes.ptr),
            .flags = .{},
        };
    }

    pub fn buildInputAssemblyStateCreateInfo(topology: vk.PrimitiveTopology) vk.PipelineInputAssemblyStateCreateInfo {
        return .{
            .topology = topology,
            .flags = .{},
            .primitive_restart_enable = vk.FALSE,
        };
    }

    pub fn buildRasterizationStateCreateInfo(polygon_mode: vk.PolygonMode) vk.PipelineRasterizationStateCreateInfo {
        return .{
            .polygon_mode = polygon_mode,
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
    }

    pub fn buildMultisampleStateCreateInfo() vk.PipelineMultisampleStateCreateInfo {
        return .{
            .rasterization_samples = .{ .@"1_bit" = true },
            .flags = .{},

            .sample_shading_enable = vk.FALSE,
            .min_sample_shading = 0,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };
    }

    pub fn buildBlendAttachmentState(transparent: bool) vk.PipelineColorBlendAttachmentState {
        return .{
            .blend_enable = if (transparent) vk.TRUE else vk.FALSE,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
            .src_color_blend_factor = .src_alpha,
            .dst_color_blend_factor = .one_minus_src_alpha,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one_minus_src_alpha,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
        };
    }

    pub fn buildViewportState() vk.PipelineViewportStateCreateInfo {
        return .{
            .viewport_count = 1,
            .p_viewports = null,
            .scissor_count = 1,
            .p_scissors = null,
            .flags = .{},
        };
    }

    pub fn buildColorBlendState(blend_attachment_states: []const vk.PipelineColorBlendAttachmentState) vk.PipelineColorBlendStateCreateInfo {
        return .{
            .attachment_count = @intCast(u32, blend_attachment_states.len),
            .p_attachments = @ptrCast([*]const vk.PipelineColorBlendAttachmentState, blend_attachment_states.ptr),

            .flags = .{},
            .logic_op_enable = vk.FALSE,
            .logic_op = undefined,
            .blend_constants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        };
    }

    pub fn buildDepthStencilState(depth_test: bool, depth_write: bool, compare_op: vk.CompareOp) vk.PipelineDepthStencilStateCreateInfo {
        return .{
            .depth_test_enable = if (depth_test) vk.TRUE else vk.FALSE,
            .depth_write_enable = if (depth_write) vk.TRUE else vk.FALSE,
            .depth_compare_op = if (depth_test) compare_op else .always,
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
    }

    pub fn buildComputePipeline(info: vk.ComputePipelineCreateInfo, pipeline_cache: *const PipelineCache) Pipeline {
        var pipeline: Pipeline = undefined;

        _ = vkfn.d.createComputePipelines(
            vkctxt.device,
            pipeline_cache.vk_ref,
            1,
            @ptrCast([*]const vk.ComputePipelineCreateInfo, &info),
            null,
            @ptrCast([*]vk.Pipeline, &pipeline.vk_ref),
        ) catch |err| {
            printVulkanError("Can't create compute pipeline", err);
        };

        return pipeline;
    }
};
