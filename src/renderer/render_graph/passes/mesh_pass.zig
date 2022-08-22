const std = @import("std");

const rg = @import("../render_graph.zig");
const vk = @import("../../../vk.zig");
const nm = @import("../../../math/math.zig");

const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../../../vulkan_wrapper/vulkan_functions.zig");

const RGPass = @import("../render_graph_pass.zig").RGPass;
const RGResource = @import("../render_graph_resource.zig").RGResource;

const Camera = @import("../../../tools/mesh_viewer/camera.zig").Camera;
const CommandBuffer = @import("../../../vulkan_wrapper/command_buffer.zig").CommandBuffer;
const Mesh = @import("../../../vulkan_wrapper/mesh.zig").Mesh;
const Pipeline = @import("../../../vulkan_wrapper/pipeline.zig").Pipeline;
const PipelineBuilder = @import("../../../vulkan_wrapper/pipeline_builder.zig").PipelineBuilder;
const PipelineCache = @import("../../../vulkan_wrapper/pipeline_cache.zig").PipelineCache;
const PipelineLayout = @import("../../../vulkan_wrapper/pipeline_layout.zig").PipelineLayout;
const RenderPass = @import("../../../vulkan_wrapper/render_pass.zig").RenderPass;
const ShaderModule = @import("../../../vulkan_wrapper/shader_module.zig").ShaderModule;
const ImageView = @import("../../../vulkan_wrapper/image_view.zig").ImageView;

const ImageWithView = @import("../resources/image_with_view.zig").ImageWithView;

const Model = @import("../../../model/model.zig").Model;

const printVulkanError = @import("../../../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

pub fn MeshPass(comptime TargetType: type) type {
    return struct {
        const VertPushConstBlock = struct { mvp: nm.mat4x4 };

        const SelfType = MeshPass(TargetType);

        rg_pass: RGPass,

        render_pass: RenderPass,
        target: *TargetType,

        vert_shader: ShaderModule,
        frag_shader: ShaderModule,

        pipeline_cache: PipelineCache,
        pipeline_layout: PipelineLayout,
        pipeline: Pipeline,

        mesh: Mesh,
        model: ?*Model,
        camera: *Camera,

        depth_buffer: *ImageWithView,

        // Accepts *ViewportTexture or *Swapchain as target
        pub fn init(
            self: *SelfType,
            comptime name: []const u8,
            target: *TargetType,
            depth_buffer: *ImageWithView,
            camera: *Camera,
        ) void {
            const res: *RGResource = rg.global_render_graph.getResource(target);

            self.rg_pass.init(name, rg.global_render_graph.allocator, passInit, passDeinit, passRender);
            self.rg_pass.appendWriteResource(res);
            self.rg_pass.appendWriteResource(rg.global_render_graph.getResource(depth_buffer));

            self.target = target;
            self.model = null;
            self.camera = camera;
            self.depth_buffer = depth_buffer;

            self.rg_pass.pipeline_start = .{ .vertex_input_bit = true };
            self.rg_pass.pipeline_end = .{ .color_attachment_output_bit = true };
        }

        pub fn deinit(self: *SelfType) void {
            self.mesh.destroy();
        }

        pub fn setModel(self: *SelfType, model: *Model) void {
            self.model = model;
            self.mesh.initFromModel(model);
            self.createPipeline();
        }

        fn passInit(rg_pass: *RGPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", rg_pass);

            const vert_code = @embedFile("mesh_pass.vert");
            self.vert_shader = ShaderModule.load(vert_code, .vertex);

            const frag_code = @embedFile("mesh_pass.frag");
            self.frag_shader = ShaderModule.load(frag_code, .fragment);

            var attachments: [2]vk.AttachmentDescription = self.getAttachmentsDescriptions();
            var views: [1]ImageView = self.getImageViews();

            self.render_pass.init(self.target, views[0..], attachments[0..]);
            self.render_pass.target_recreated_callback = targetRecreatedCallback;

            self.pipeline_cache = PipelineCache.createEmpty();
            self.createPipelineLayout();
        }

        fn passDeinit(render_pass: *RGPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", render_pass);
            self.render_pass.destroy();

            self.pipeline.destroy();
            self.pipeline_layout.destroy();
            self.pipeline_cache.destroy();

            self.vert_shader.destroy();
            self.frag_shader.destroy();
        }

        fn passRender(render_pass: *RGPass, command_buffer: *CommandBuffer, frame_index: u32) void {
            _ = frame_index;

            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", render_pass);

            const clear_color: [2]vk.ClearValue = .{
                .{ .color = .{ .float_32 = [_]f32{ 0.6, 0.3, 0.6, 1.0 } } },
                .{ .depth_stencil = .{ .depth = 1.0, .stencil = 0.0 } },
            };
            const render_pass_info: vk.RenderPassBeginInfo = .{
                .render_pass = self.render_pass.vk_ref,
                .framebuffer = self.render_pass.getCurrentFramebuffer().vk_ref,
                .render_area = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = self.target.image_extent,
                },
                .clear_value_count = @intCast(u32, clear_color.len),
                .p_clear_values = @ptrCast([*]const vk.ClearValue, &clear_color[0]),
            };

            vkfn.d.cmdBeginRenderPass(command_buffer.vk_ref, render_pass_info, .@"inline");
            defer vkfn.d.cmdEndRenderPass(command_buffer.vk_ref);

            if (self.model == null) return;

            vkfn.d.cmdBindPipeline(command_buffer.vk_ref, .graphics, self.pipeline.vk_ref);

            const viewport_info: vk.Viewport = .{
                .width = @intToFloat(f32, self.target.image_extent.width),
                .height = @intToFloat(f32, self.target.image_extent.height),
                .min_depth = 0.0,
                .max_depth = 1.0,
                .x = 0,
                .y = 0,
            };

            vkfn.d.cmdSetViewport(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Viewport, &viewport_info));

            var scissor_rect: vk.Rect2D = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.target.image_extent,
            };

            const scissor_rect_ptr: *vk.Rect2D = &scissor_rect;
            vkfn.d.cmdSetScissor(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Rect2D, scissor_rect_ptr));

            var push_const_block: VertPushConstBlock = .{
                .mvp = nm.Mat4x4.mul(
                    self.camera.projectionFn(self.camera, nm.rad(60.0), viewport_info.width / viewport_info.height, 0.0001, 100.0),
                    self.camera.viewMatrix(),
                ),
            };

            vkfn.d.cmdPushConstants(
                command_buffer.vk_ref,
                self.pipeline_layout.vk_ref,
                .{ .vertex_bit = true },
                0,
                @sizeOf(VertPushConstBlock),
                @ptrCast([*]const VertPushConstBlock, &push_const_block),
            );

            self.mesh.bind(command_buffer);
            vkfn.d.cmdDrawIndexed(command_buffer.vk_ref, @intCast(u32, self.model.?.indices.?.len), 1, 0, 0, 0);
        }

        fn targetRecreatedCallback(render_pass: *RenderPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "render_pass", render_pass);

            const extent: vk.Extent3D = .{
                .width = self.target.image_extent.width,
                .height = self.target.image_extent.height,
                .depth = 1.0,
            };
            self.depth_buffer.resize(extent);

            var views: [1]ImageView = self.getImageViews();
            self.render_pass.recreateFramebuffers(self.target, views[0..]);
        }

        fn getAttachmentsDescriptions(self: *SelfType) [2]vk.AttachmentDescription {
            return .{
                .{
                    .format = self.target.image_format,
                    .samples = .{ .@"1_bit" = true },
                    .load_op = self.rg_pass.load_op,
                    .store_op = .store,
                    .stencil_load_op = .dont_care,
                    .stencil_store_op = .dont_care,
                    .initial_layout = self.rg_pass.initial_layout,
                    .final_layout = self.rg_pass.final_layout,
                    .flags = .{},
                },
                .{
                    .format = self.depth_buffer.image.format,
                    .samples = .{ .@"1_bit" = true },
                    .load_op = .clear,
                    .store_op = .store,
                    .stencil_load_op = .clear,
                    .stencil_store_op = .dont_care,
                    .initial_layout = .@"undefined",
                    .final_layout = .depth_stencil_attachment_optimal,
                    .flags = .{},
                },
            };
        }

        fn getImageViews(self: *SelfType) [1]ImageView {
            return .{self.depth_buffer.view};
        }

        fn createPipelineLayout(self: *SelfType) void {
            const push_constant_range: [1]vk.PushConstantRange = [_]vk.PushConstantRange{
                .{
                    .stage_flags = .{ .vertex_bit = true },
                    .offset = 0,
                    .size = @sizeOf(VertPushConstBlock),
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
                PipelineBuilder.buildShaderStageCreateInfo(.{ .fragment_bit = true }, &self.frag_shader),
            };

            const color_blend_attachments = [_]vk.PipelineColorBlendAttachmentState{
                PipelineBuilder.buildBlendAttachmentState(false),
            };

            var vertex_attributes = self.model.?.generateAttributeDescriptions(rg.global_render_graph.allocator);
            defer rg.global_render_graph.allocator.free(vertex_attributes);

            var pipeline_builder: PipelineBuilder = .{
                .shader_stages = shader_stages[0..],
                .vertex_input_state = PipelineBuilder.buildVertexInputStateCreateInfo(&.{self.model.?.generateInputBindings()}, vertex_attributes),
                .input_assembly_state = PipelineBuilder.buildInputAssemblyStateCreateInfo(.triangle_list),
                .rasterization_state = PipelineBuilder.buildRasterizationStateCreateInfo(.fill),
                .color_blend_attachment = color_blend_attachments[0],
                .color_blend_state = PipelineBuilder.buildColorBlendState(color_blend_attachments[0..]),
                .multisample_state = PipelineBuilder.buildMultisampleStateCreateInfo(),
                .depth_stencil_state = PipelineBuilder.buildDepthStencilState(true, true, .less_or_equal),
                .viewport_state = PipelineBuilder.buildViewportState(),

                .pipeline_cache = &self.pipeline_cache,
                .pipeline_layout = &self.pipeline_layout,
            };
            self.pipeline = pipeline_builder.build(&self.render_pass);
        }
    };
}
