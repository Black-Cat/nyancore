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
const Pipeline = @import("../../../vulkan_wrapper/pipeline.zig").Pipeline;
const PipelineBuilder = @import("../../../vulkan_wrapper/pipeline_builder.zig").PipelineBuilder;
const PipelineCache = @import("../../../vulkan_wrapper/pipeline_cache.zig").PipelineCache;
const PipelineLayout = @import("../../../vulkan_wrapper/pipeline_layout.zig").PipelineLayout;

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

        pipeline_cache: PipelineCache,
        pipeline_layout: PipelineLayout,
        pipeline: Pipeline,

        vert_shader: ShaderModule,

        frag_shader: *ShaderModule,
        frag_push_const_size: usize,
        frag_push_const_block: *const anyopaque,

        custom_scissors: ?*vk.Rect2D,

        // Accepts *ViewportTexture or *Swapchain as target
        pub fn init(
            self: *SelfType,
            comptime name: []const u8,
            target: *TargetType,
            frag_shader: *ShaderModule,
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

            self.pipeline_cache = PipelineCache.createEmpty();
            self.createPipelineLayout();
            self.createPipeline();
        }

        fn passDeinit(render_pass: *RGPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", render_pass);
            self.render_pass.destroy();

            self.pipeline.destroy();
            self.pipeline_layout.destroy();
            self.pipeline_cache.destroy();

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

            vkfn.d.cmdBindPipeline(command_buffer.vk_ref, .graphics, self.pipeline.vk_ref);

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
                self.pipeline_layout.vk_ref,
                .{ .vertex_bit = true },
                0,
                @sizeOf(VertPushConstBlock),
                @ptrCast([*]const VertPushConstBlock, &push_const_block),
            );

            vkfn.d.cmdPushConstants(
                command_buffer.vk_ref,
                self.pipeline_layout.vk_ref,
                .{ .fragment_bit = true },
                @sizeOf(VertPushConstBlock),
                @intCast(u32, self.frag_push_const_size),
                self.frag_push_const_block,
            );

            vkfn.d.cmdDraw(command_buffer.vk_ref, 3, 1, 0, 0);
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

            self.pipeline_layout = PipelineLayout.create(&.{}, push_constant_range[0..]);
        }

        fn recreatePipeline(self: *SelfType) void {
            self.pipeline.destroy();
            self.createPipeline();
        }

        pub fn recreatePipelineOnShaderChange(pass: *RGPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", pass);
            self.recreatePipeline();
        }

        fn createPipeline(self: *SelfType) void {
            const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
                PipelineBuilder.buildShaderStageCreateInfo(.{ .vertex_bit = true }, &self.vert_shader),
                PipelineBuilder.buildShaderStageCreateInfo(.{ .fragment_bit = true }, self.frag_shader),
            };

            const color_blend_attachments = [_]vk.PipelineColorBlendAttachmentState{
                PipelineBuilder.buildBlendAttachmentState(false),
            };

            var pipeline_builder: PipelineBuilder = .{
                .shader_stages = shader_stages[0..],
                .vertex_input_state = PipelineBuilder.buildVertexInputStateCreateInfo(&.{}, &.{}),
                .input_assembly_state = PipelineBuilder.buildInputAssemblyStateCreateInfo(.triangle_list),
                .rasterization_state = PipelineBuilder.buildRasterizationStateCreateInfo(.fill),
                .color_blend_attachment = color_blend_attachments[0],
                .color_blend_state = PipelineBuilder.buildColorBlendState(color_blend_attachments[0..]),
                .multisample_state = PipelineBuilder.buildMultisampleStateCreateInfo(),
                .depth_stencil_state = PipelineBuilder.buildDepthStencilState(false, false, .always),
                .viewport_state = PipelineBuilder.buildViewportState(),

                .pipeline_cache = &self.pipeline_cache,
                .pipeline_layout = &self.pipeline_layout,
            };
            self.pipeline = pipeline_builder.build(&self.render_pass);
        }
    };
}
