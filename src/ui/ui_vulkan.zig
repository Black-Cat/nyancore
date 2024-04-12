const c = @import("../c.zig");
const vk = @import("../vk.zig");
const std = @import("std");

usingnamespace @cImport({
    @cInclude("fira_sans_regular.h");
});

const vkctxt = @import("../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../vulkan_wrapper/vulkan_functions.zig");

const Buffer = vkctxt.Buffer;
const UI = @import("ui.zig").UI;

const printError = @import("../application/print_error.zig").printError;
const printVulkanError = @import("../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const rg = @import("../renderer/render_graph/render_graph.zig");
const RenderGraph = rg.RenderGraph;

const CommandBuffer = @import("../vulkan_wrapper/command_buffer.zig").CommandBuffer;
const DescriptorPool = @import("../vulkan_wrapper/descriptor_pool.zig").DescriptorPool;
const DescriptorSetLayout = @import("../vulkan_wrapper/descriptor_set_layout.zig").DescriptorSetLayout;
const DescriptorSets = @import("../vulkan_wrapper/descriptor_sets.zig").DescriptorSets;
const Mesh = @import("../vulkan_wrapper/mesh.zig").Mesh;
const Pipeline = @import("../vulkan_wrapper/pipeline.zig").Pipeline;
const PipelineBuilder = @import("../vulkan_wrapper/pipeline_builder.zig").PipelineBuilder;
const PipelineCache = @import("../vulkan_wrapper/pipeline_cache.zig").PipelineCache;
const PipelineLayout = @import("../vulkan_wrapper/pipeline_layout.zig").PipelineLayout;
const RenderPass = @import("../vulkan_wrapper/render_pass.zig").RenderPass;
const Sampler = @import("../vulkan_wrapper/sampler.zig").Sampler;
const ShaderModule = @import("../vulkan_wrapper/shader_module.zig").ShaderModule;
const SingleCommandBuffer = @import("../vulkan_wrapper/single_command_buffer.zig").SingleCommandBuffer;
const Texture = @import("../vulkan_wrapper/texture.zig").Texture;
const TransferContext = @import("../vulkan_wrapper/transfer_context.zig").TransferContext;

const PushConstBlock = extern struct {
    scale_translate: [4]f32,
};

pub const UIVulkanContext = struct {
    parent: *UI,
    font_texture: Texture,
    font_sampler: Sampler,

    descriptor_pool: DescriptorPool,
    descriptor_set_layout: DescriptorSetLayout,
    descriptor_sets: DescriptorSets,

    pipeline_cache: PipelineCache,

    frag_shader: ShaderModule,
    vert_shader: ShaderModule,

    meshes: []Mesh,

    render_pass: RenderPass,
    pipeline_layout: PipelineLayout,
    pipeline: Pipeline,

    pub fn init(self: *UIVulkanContext, parent: *UI) void {
        self.parent = parent;

        self.initResources();
    }
    pub fn deinit(self: *UIVulkanContext) void {
        vkfn.d.deviceWaitIdle(vkctxt.device) catch return;

        for (self.meshes) |*mesh|
            mesh.destroy();
        vkctxt.allocator.free(self.meshes);

        self.pipeline.destroy();
        self.pipeline_layout.destroy();
        self.render_pass.destroy();

        self.vert_shader.destroy();
        self.frag_shader.destroy();

        self.pipeline_cache.destroy();

        self.descriptor_sets.deinit();
        self.descriptor_set_layout.deinit();
        self.descriptor_pool.deinit();

        self.font_sampler.deinit();
        self.font_texture.deinit();
    }
    pub fn render(self: *UIVulkanContext, command_buffer: *CommandBuffer, frame_index: u32) void {
        self.updateBuffers(frame_index);

        const io: *c.ImGuiIO = c.igGetIO();

        const clear_color: vk.ClearValue = .{ .color = .{ .float_32 = [_]f32{ 0.6, 0.3, 0.6, 1.0 } } };
        const render_pass_info: vk.RenderPassBeginInfo = .{
            .render_pass = self.render_pass.vk_ref,
            .framebuffer = self.render_pass.getCurrentFramebuffer().vk_ref,
            .render_area = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = rg.global_render_graph.final_swapchain.image_extent,
            },
            .clear_value_count = 1,
            .p_clear_values = @ptrCast(&clear_color),
        };

        vkfn.d.cmdBeginRenderPass(command_buffer.vk_ref, &render_pass_info, .@"inline");
        defer vkfn.d.cmdEndRenderPass(command_buffer.vk_ref);

        self.descriptor_sets.bind(.graphics, command_buffer, &self.pipeline_layout);
        var current_descriptor_sets: *DescriptorSets = &self.descriptor_sets;

        vkfn.d.cmdBindPipeline(command_buffer.vk_ref, .graphics, self.pipeline.vk_ref);

        const viewport: vk.Viewport = .{
            .width = io.DisplaySize.x,
            .height = io.DisplaySize.y,
            .min_depth = 0.0,
            .max_depth = 1.0,

            .x = 0,
            .y = 0,
        };
        vkfn.d.cmdSetViewport(command_buffer.vk_ref, 0, 1, @ptrCast(&viewport));

        const push_const_block: PushConstBlock = .{
            .scale_translate = [4]f32{ 2.0 / viewport.width, 2.0 / viewport.height, -1.0, -1.0 },
        };
        vkfn.d.cmdPushConstants(
            command_buffer.vk_ref,
            self.pipeline_layout.vk_ref,
            .{ .vertex_bit = true },
            0,
            @sizeOf(PushConstBlock),
            @ptrCast(&push_const_block),
        );

        // Render commands
        const draw_data: *c.ImDrawData = c.igGetDrawData() orelse return;

        var vertex_offset: i32 = 0;
        var index_offset: u32 = 0;

        if (draw_data.CmdListsCount == 0)
            return;

        self.meshes[frame_index].bind(command_buffer);

        const clip_off: c.ImVec2 = draw_data.DisplayPos;
        const clip_scale: c.ImVec2 = draw_data.FramebufferScale;

        var i: usize = 0;
        while (i < draw_data.CmdListsCount) : (i += 1) {
            const cmd_list: *c.ImDrawList = draw_data.CmdLists[i];
            var j: usize = 0;
            while (j < cmd_list.CmdBuffer.Size) : (j += 1) {
                const pcmd: c.ImDrawCmd = cmd_list.CmdBuffer.Data[j];

                const clip_rect: c.ImVec4 = .{
                    .x = @max(0.0, (pcmd.ClipRect.x - clip_off.x) * clip_scale.x),
                    .y = @max(0.0, (pcmd.ClipRect.y - clip_off.y) * clip_scale.y),
                    .z = (pcmd.ClipRect.z - clip_off.x) * clip_scale.x,
                    .w = (pcmd.ClipRect.w - clip_off.y) * clip_scale.y,
                };

                const scissor_rect: vk.Rect2D = .{
                    .offset = .{
                        .x = @intFromFloat(clip_rect.x),
                        .y = @intFromFloat(clip_rect.y),
                    },
                    .extent = .{
                        .width = @intFromFloat(pcmd.ClipRect.z - pcmd.ClipRect.x),
                        .height = @intFromFloat(pcmd.ClipRect.w - pcmd.ClipRect.y),
                    },
                };
                vkfn.d.cmdSetScissor(command_buffer.vk_ref, 0, 1, @ptrCast(&scissor_rect));

                // Bind descriptor that user specified with igImage or default font descriptor
                const descriptors_ptr: *DescriptorSets = if (pcmd.TextureId) |ti|
                    @ptrCast(@alignCast(ti))
                else
                    &self.descriptor_sets;

                if (descriptors_ptr != current_descriptor_sets) {
                    current_descriptor_sets = descriptors_ptr;
                    current_descriptor_sets.bind(.graphics, command_buffer, &self.pipeline_layout);
                }

                vkfn.d.cmdDrawIndexed(command_buffer.vk_ref, pcmd.ElemCount, 1, index_offset, vertex_offset, 0);
                index_offset += pcmd.ElemCount;
            }
            vertex_offset += cmd_list.VtxBuffer.Size;
        }
    }

    fn updateBuffers(self: *UIVulkanContext, frame_index: u32) void {
        const draw_data: *c.ImDrawData = c.igGetDrawData() orelse return;

        const vertex_buffer_size: vk.DeviceSize = @as(u64, @intCast(draw_data.TotalVtxCount)) * @sizeOf(c.ImDrawVert);
        const index_buffer_size: vk.DeviceSize = @as(u64, @intCast(draw_data.TotalIdxCount)) * @sizeOf(c.ImDrawIdx);

        if (vertex_buffer_size == 0 or index_buffer_size == 0)
            return;

        // Update only if vertex or index count has changed
        const mesh: *Mesh = &self.meshes[frame_index];
        if (mesh.vertex_buffer.allocation.allocation_info.size < vertex_buffer_size)
            mesh.vertex_buffer.resize(vertex_buffer_size);

        if (mesh.index_buffer.allocation.allocation_info.size < index_buffer_size)
            mesh.index_buffer.resize(index_buffer_size);

        var vtx_dst: [*]c.ImDrawVert align(4) = @ptrCast(@alignCast(mesh.vertex_buffer.allocation.mapped_memory));
        var idx_dst: [*]c.ImDrawIdx align(2) = @ptrCast(@alignCast(mesh.index_buffer.allocation.mapped_memory));

        var n: usize = 0;
        while (n < draw_data.CmdListsCount) : (n += 1) {
            const cmd_list: *c.ImDrawList = draw_data.CmdLists[n];
            @memcpy(
                vtx_dst[0..@intCast(cmd_list.VtxBuffer.Size)],
                cmd_list.VtxBuffer.Data[0..@intCast(cmd_list.VtxBuffer.Size)],
            );
            @memcpy(
                idx_dst[0..@intCast(cmd_list.IdxBuffer.Size)],
                cmd_list.IdxBuffer.Data[0..@intCast(cmd_list.IdxBuffer.Size)],
            );
            vtx_dst += @as(usize, @intCast(cmd_list.VtxBuffer.Size));
            idx_dst += @as(usize, @intCast(cmd_list.IdxBuffer.Size));
        }

        mesh.vertex_buffer.flushWhole();
        mesh.index_buffer.flushWhole();
    }

    fn createRenderPass(self: *UIVulkanContext) void {
        var color_attachment: [1]vk.AttachmentDescription = .{.{
            .format = rg.global_render_graph.final_swapchain.image_format,
            .samples = .{ .@"1_bit" = true },
            .load_op = self.parent.rg_pass.load_op,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = self.parent.rg_pass.initial_layout,
            .final_layout = self.parent.rg_pass.final_layout,
            .flags = .{},
        }};

        self.render_pass.init(&rg.global_render_graph.final_swapchain, &.{}, color_attachment[0..]);
        self.render_pass.target_recreated_callback = targetRecreatedCallback;
    }

    fn targetRecreatedCallback(render_pass: *RenderPass) void {
        const self: *UIVulkanContext = @fieldParentPtr(UIVulkanContext, "render_pass", render_pass);
        self.render_pass.recreateFramebuffers(&rg.global_render_graph.final_swapchain, &.{});
    }

    fn createGraphicsPipeline(self: *UIVulkanContext) void {
        const push_constant_range: vk.PushConstantRange = .{
            .stage_flags = .{ .vertex_bit = true },
            .offset = 0,
            .size = @sizeOf(PushConstBlock),
        };

        self.pipeline_layout = PipelineLayout.create(
            &[_]vk.DescriptorSetLayout{self.descriptor_set_layout.vk_ref},
            &[_]vk.PushConstantRange{push_constant_range},
        );

        const vertex_input_bindings = [_]vk.VertexInputBindingDescription{
            .{
                .binding = 0,
                .stride = @sizeOf(c.ImDrawVert),
                .input_rate = .vertex,
            },
        };

        const vertex_input_attributes = [_]vk.VertexInputAttributeDescription{
            .{
                .binding = 0,
                .location = 0,
                .format = .r32g32_sfloat,
                .offset = @offsetOf(c.ImDrawVert, "pos"),
            },
            .{
                .binding = 0,
                .location = 1,
                .format = .r32g32_sfloat,
                .offset = @offsetOf(c.ImDrawVert, "uv"),
            },
            .{
                .binding = 0,
                .location = 2,
                .format = .r8g8b8a8_unorm,
                .offset = @offsetOf(c.ImDrawVert, "col"),
            },
        };

        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            PipelineBuilder.buildShaderStageCreateInfo(.{ .vertex_bit = true }, &self.vert_shader),
            PipelineBuilder.buildShaderStageCreateInfo(.{ .fragment_bit = true }, &self.frag_shader),
        };

        const color_blend_attachments = [_]vk.PipelineColorBlendAttachmentState{
            PipelineBuilder.buildBlendAttachmentState(true),
        };

        var pipeline_builder: PipelineBuilder = .{
            .shader_stages = shader_stages[0..],
            .vertex_input_state = PipelineBuilder.buildVertexInputStateCreateInfo(vertex_input_bindings[0..], vertex_input_attributes[0..]),
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

    fn initFonts(self: *UIVulkanContext) void {
        var io: c.ImGuiIO = c.igGetIO().*;

        var scale: [2]f32 = undefined;
        c.glfwGetWindowContentScale(self.parent.app.window, &scale[0], &scale[1]);

        var ranges: c.ImVector_ImWchar = undefined;
        c.ImVector_ImWchar_Init(&ranges);
        defer c.ImVector_ImWchar_UnInit(&ranges);

        var range_builder: *c.ImFontGlyphRangesBuilder = c.ImFontGlyphRangesBuilder_ImFontGlyphRangesBuilder();
        defer c.ImFontGlyphRangesBuilder_destroy(range_builder);

        c.ImFontGlyphRangesBuilder_AddRanges(range_builder, c.ImFontAtlas_GetGlyphRangesDefault(io.Fonts));
        c.ImFontGlyphRangesBuilder_AddRanges(range_builder, c.ImFontAtlas_GetGlyphRangesCyrillic(io.Fonts));
        c.ImFontGlyphRangesBuilder_AddRanges(range_builder, c.ImFontAtlas_GetGlyphRangesChineseSimplifiedCommon(io.Fonts));

        c.ImFontGlyphRangesBuilder_BuildRanges(range_builder, &ranges);

        _ = c.ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(io.Fonts, @ptrCast(&c.NotoSans_compressed_data_base85), 15.0 * scale[1], null, ranges.Data);

        var font_data: [*c]u8 = undefined;
        var tex_dim: [2]c_int = undefined;
        c.ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, @ptrCast(&font_data), &tex_dim[0], &tex_dim[1], null);

        const tex_size: usize = @intCast(4 * tex_dim[0] * tex_dim[1]);

        var font_data_slice: []u8 = undefined;
        font_data_slice.ptr = font_data;
        font_data_slice.len = tex_size;

        const extent: vk.Extent3D = .{
            .width = @intCast(tex_dim[0]),
            .height = @intCast(tex_dim[1]),
            .depth = 1.0,
        };
        self.font_texture.init(extent, .r8g8b8a8_unorm, .{ .transfer_dst_bit = true, .sampled_bit = true });
        rg.global_render_graph.addResource(&self.font_texture, "Font Texture");
        TransferContext.transfer_image(&self.font_texture.image, .shader_read_only_optimal, font_data_slice);

        const pool_size: vk.DescriptorPoolSize = .{
            .type = .combined_image_sampler,
            .descriptor_count = 1,
        };

        self.descriptor_pool.init(&.{pool_size}, 2);

        const set_layout_bindings: vk.DescriptorSetLayoutBinding = .{
            .stage_flags = .{ .fragment_bit = true },
            .binding = 0,
            .descriptor_count = 1,
            .descriptor_type = .combined_image_sampler,
            .p_immutable_samplers = undefined,
        };

        self.descriptor_set_layout.init(&.{set_layout_bindings});
        self.descriptor_sets.init(&self.descriptor_pool, &[_]vk.DescriptorSetLayout{self.descriptor_set_layout.vk_ref}, 1);

        self.font_sampler.sampler_info = Sampler.default_sampler_info;
        self.font_sampler.init();

        const font_descriptor_image_info: vk.DescriptorImageInfo = .{
            .sampler = self.font_sampler.vk_ref,
            .image_view = self.font_texture.view.vk_ref,
            .image_layout = .shader_read_only_optimal,
        };

        self.descriptor_sets.write(0, &[_]vk.DescriptorImageInfo{font_descriptor_image_info});
    }

    fn initResources(self: *UIVulkanContext) void {
        self.initFonts();

        self.pipeline_cache = PipelineCache.createEmpty();

        const ui_vert = @embedFile("ui.vert");
        const ui_frag = @embedFile("ui.frag");
        self.vert_shader = ShaderModule.load(ui_vert, .vertex);
        self.frag_shader = ShaderModule.load(ui_frag, .fragment);

        self.createRenderPass();
        self.createGraphicsPipeline();

        const mesh_count: u32 = rg.global_render_graph.in_flight;
        self.meshes = vkctxt.allocator.alloc(Mesh, mesh_count) catch unreachable;

        for (self.meshes) |*mesh|
            mesh.init(.sequential, @sizeOf(c.ImDrawVert), 1000, .uint16, 300);
    }
};
