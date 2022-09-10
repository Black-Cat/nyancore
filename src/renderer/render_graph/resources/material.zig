const nm = @import("../../../math/math.zig");
const vk = @import("../../../vk.zig");

const Pipeline = @import("../../../vulkan_wrapper/pipeline.zig").Pipeline;
const PipelineBuilder = @import("../../../vulkan_wrapper/pipeline_builder.zig").PipelineBuilder;
const PipelineCache = @import("../../../vulkan_wrapper/pipeline_cache.zig").PipelineCache;
const PipelineLayout = @import("../../../vulkan_wrapper/pipeline_layout.zig").PipelineLayout;
const RenderPass = @import("../../../vulkan_wrapper/render_pass.zig").RenderPass;

pub const Material = struct {
    pipeline: Pipeline = undefined,
    pipeline_layout: PipelineLayout = undefined,

    pub fn init(
        self: *Material,
        shader_stages: []const vk.PipelineShaderStageCreateInfo,
        color_blend_attachments: []const vk.PipelineColorBlendAttachmentState,
        vertex_attributes: []const vk.VertexInputAttributeDescription,
        vertex_input_bindings: vk.VertexInputBindingDescription,
        descriptor_bindings: []vk.DescriptorSetLayout,
        pipeline_cache: *PipelineCache,
        render_pass: *RenderPass,
    ) void {
        self.pipeline_layout = PipelineLayout.create(descriptor_bindings, &.{});

        var pipeline_builder: PipelineBuilder = .{
            .shader_stages = shader_stages[0..],
            .vertex_input_state = PipelineBuilder.buildVertexInputStateCreateInfo(&.{vertex_input_bindings}, vertex_attributes),
            .input_assembly_state = PipelineBuilder.buildInputAssemblyStateCreateInfo(.triangle_list),
            .rasterization_state = PipelineBuilder.buildRasterizationStateCreateInfo(.fill),
            .color_blend_attachment = color_blend_attachments[0],
            .color_blend_state = PipelineBuilder.buildColorBlendState(color_blend_attachments[0..]),
            .multisample_state = PipelineBuilder.buildMultisampleStateCreateInfo(),
            .depth_stencil_state = PipelineBuilder.buildDepthStencilState(true, true, .less_or_equal),
            .viewport_state = PipelineBuilder.buildViewportState(),

            .pipeline_cache = pipeline_cache,
            .pipeline_layout = &self.pipeline_layout,
        };
        self.pipeline = pipeline_builder.build(render_pass);
    }

    pub fn deinit(self: *Material) void {
        self.pipeline.destroy();
        self.pipeline_layout.destroy();
    }
};
