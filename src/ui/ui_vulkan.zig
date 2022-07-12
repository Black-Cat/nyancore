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
const Texture = @import("../renderer/render_graph/resources/texture.zig").Texture;
const CommandBuffer = @import("../vulkan_wrapper/command_buffer.zig").CommandBuffer;
const SingleCommandBuffer = @import("../vulkan_wrapper/single_command_buffer.zig").SingleCommandBuffer;
const RenderPass = @import("../vulkan_wrapper/render_pass.zig").RenderPass;
const ShaderModule = @import("../vulkan_wrapper/shader_module.zig").ShaderModule;

const PushConstBlock = packed struct {
    scale_translate: [4]f32,
};

pub const UIVulkanContext = struct {
    parent: *UI,
    font_texture: Texture,

    descriptor_pool: vk.DescriptorPool,
    descriptor_set_layout: vk.DescriptorSetLayout,
    descriptor_set: vk.DescriptorSet,

    pipeline_cache: vk.PipelineCache,

    frag_shader: ShaderModule,
    vert_shader: ShaderModule,

    vertex_buffers: []Buffer,
    index_buffers: []Buffer,

    vertex_buffer_counts: []usize,
    index_buffer_counts: []usize,

    render_pass: RenderPass,
    pipeline_layout: vk.PipelineLayout,
    pipeline: vk.Pipeline,

    pub fn init(self: *UIVulkanContext, parent: *UI) void {
        self.parent = parent;

        self.initResources();
    }
    pub fn deinit(self: *UIVulkanContext) void {
        vkfn.d.deviceWaitIdle(vkctxt.device) catch return;
        for (self.vertex_buffers) |*buffer|
            if (buffer.buffer != .null_handle)
                buffer.destroy();
        vkctxt.allocator.free(self.vertex_buffers);
        for (self.index_buffers) |*buffer|
            if (buffer.buffer != .null_handle)
                buffer.destroy();
        vkctxt.allocator.free(self.index_buffers);

        vkctxt.allocator.free(self.vertex_buffer_counts);
        vkctxt.allocator.free(self.index_buffer_counts);

        vkfn.d.destroyPipeline(vkctxt.device, self.pipeline, null);
        vkfn.d.destroyPipelineLayout(vkctxt.device, self.pipeline_layout, null);
        self.render_pass.destroy();

        self.vert_shader.destroy();
        self.frag_shader.destroy();

        vkfn.d.destroyPipelineCache(vkctxt.device, self.pipeline_cache, null);

        vkfn.d.destroyDescriptorSetLayout(vkctxt.device, self.descriptor_set_layout, null);
        vkfn.d.destroyDescriptorPool(vkctxt.device, self.descriptor_pool, null);

        self.font_texture.destroy();
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
            .p_clear_values = @ptrCast([*]const vk.ClearValue, &clear_color),
        };

        vkfn.d.cmdBeginRenderPass(command_buffer.vk_ref, render_pass_info, .@"inline");
        defer vkfn.d.cmdEndRenderPass(command_buffer.vk_ref);

        vkfn.d.cmdBindDescriptorSets(command_buffer.vk_ref, .graphics, self.pipeline_layout, 0, 1, @ptrCast([*]const vk.DescriptorSet, &self.descriptor_set), 0, undefined);
        vkfn.d.cmdBindPipeline(command_buffer.vk_ref, .graphics, self.pipeline);

        const viewport: vk.Viewport = .{
            .width = io.DisplaySize.x,
            .height = io.DisplaySize.y,
            .min_depth = 0.0,
            .max_depth = 1.0,

            .x = 0,
            .y = 0,
        };
        vkfn.d.cmdSetViewport(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));

        const push_const_block: PushConstBlock = .{
            .scale_translate = [4]f32{ 2.0 / viewport.width, 2.0 / viewport.height, -1.0, -1.0 },
        };
        vkfn.d.cmdPushConstants(command_buffer.vk_ref, self.pipeline_layout, .{ .vertex_bit = true }, 0, @sizeOf(PushConstBlock), @ptrCast([*]const PushConstBlock, &push_const_block));

        // Render commands
        const draw_data: *c.ImDrawData = c.igGetDrawData() orelse return;

        var vertex_offset: i32 = 0;
        var index_offset: u32 = 0;

        if (draw_data.CmdListsCount == 0)
            return;

        const offset: u64 = 0;
        vkfn.d.cmdBindVertexBuffers(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Buffer, &self.vertex_buffers[frame_index].buffer), @ptrCast([*]const u64, &offset));
        vkfn.d.cmdBindIndexBuffer(command_buffer.vk_ref, self.index_buffers[frame_index].buffer, 0, .uint16);

        const clip_off: c.ImVec2 = draw_data.DisplayPos;
        const clip_scale: c.ImVec2 = draw_data.FramebufferScale;

        var i: usize = 0;
        while (i < draw_data.CmdListsCount) : (i += 1) {
            const cmd_list: *c.ImDrawList = draw_data.CmdLists[i];
            var j: usize = 0;
            while (j < cmd_list.CmdBuffer.Size) : (j += 1) {
                const pcmd: c.ImDrawCmd = cmd_list.CmdBuffer.Data[j];

                const clip_rect: c.ImVec4 = .{
                    .x = std.math.max(0.0, (pcmd.ClipRect.x - clip_off.x) * clip_scale.x),
                    .y = std.math.max(0.0, (pcmd.ClipRect.y - clip_off.y) * clip_scale.y),
                    .z = (pcmd.ClipRect.z - clip_off.x) * clip_scale.x,
                    .w = (pcmd.ClipRect.w - clip_off.y) * clip_scale.y,
                };

                const scissor_rect: vk.Rect2D = .{
                    .offset = .{
                        .x = @floatToInt(i32, clip_rect.x),
                        .y = @floatToInt(i32, clip_rect.y),
                    },
                    .extent = .{
                        .width = @floatToInt(u32, pcmd.ClipRect.z - pcmd.ClipRect.x),
                        .height = @floatToInt(u32, pcmd.ClipRect.w - pcmd.ClipRect.y),
                    },
                };
                vkfn.d.cmdSetScissor(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor_rect));

                // Bind descriptor that user specified with igImage
                if (pcmd.TextureId != null) {
                    const alignment: u26 = @alignOf([*]const vk.DescriptorSet);
                    const descriptor_set: [*]const vk.DescriptorSet = @ptrCast([*]const vk.DescriptorSet, @alignCast(alignment, pcmd.TextureId.?));
                    vkfn.d.cmdBindDescriptorSets(command_buffer.vk_ref, .graphics, self.pipeline_layout, 0, 1, descriptor_set, 0, undefined);
                }

                vkfn.d.cmdDrawIndexed(command_buffer.vk_ref, pcmd.ElemCount, 1, index_offset, vertex_offset, 0);
                index_offset += pcmd.ElemCount;

                // Return font descriptor
                if (pcmd.TextureId != null)
                    vkfn.d.cmdBindDescriptorSets(command_buffer.vk_ref, .graphics, self.pipeline_layout, 0, 1, @ptrCast([*]const vk.DescriptorSet, &self.descriptor_set), 0, undefined);
            }
            vertex_offset += cmd_list.VtxBuffer.Size;
        }
    }

    fn updateBuffers(self: *UIVulkanContext, frame_index: u32) void {
        const draw_data: *c.ImDrawData = c.igGetDrawData() orelse return;

        const vertex_buffer_size: vk.DeviceSize = @intCast(u64, draw_data.TotalVtxCount) * @sizeOf(c.ImDrawVert);
        const index_buffer_size: vk.DeviceSize = @intCast(u64, draw_data.TotalIdxCount) * @sizeOf(c.ImDrawIdx);

        if (vertex_buffer_size == 0 or index_buffer_size == 0)
            return;

        // Update only if vertex or index count has changed
        if (self.vertex_buffers[frame_index].buffer == .null_handle or self.vertex_buffer_counts[frame_index] < draw_data.TotalVtxCount) {
            if (self.vertex_buffers[frame_index].buffer != .null_handle) {
                vkfn.d.queueWaitIdle(vkctxt.present_queue) catch |err| {
                    printVulkanError("Can't wait present queue", err);
                };
                self.vertex_buffers[frame_index].destroy();
            }

            self.vertex_buffers[frame_index].init(vertex_buffer_size, .{ .vertex_buffer_bit = true }, .{ .host_visible_bit = true });
            self.vertex_buffer_counts[frame_index] = @intCast(usize, draw_data.TotalVtxCount);
        }

        if (self.index_buffers[frame_index].buffer == .null_handle or self.index_buffer_counts[frame_index] < draw_data.TotalIdxCount) {
            if (self.index_buffers[frame_index].buffer != .null_handle) {
                vkfn.d.queueWaitIdle(vkctxt.present_queue) catch |err| {
                    printVulkanError("Can't wait present queue", err);
                };
                self.index_buffers[frame_index].destroy();
            }

            self.index_buffers[frame_index].init(index_buffer_size, .{ .index_buffer_bit = true }, .{ .host_visible_bit = true });
            self.index_buffer_counts[frame_index] = @intCast(usize, draw_data.TotalIdxCount);
        }

        var vtx_dst: [*]c.ImDrawVert = @ptrCast([*]c.ImDrawVert, @alignCast(@alignOf(c.ImDrawVert), self.vertex_buffers[frame_index].mapped_memory));
        var idx_dst: [*]c.ImDrawIdx = @ptrCast([*]c.ImDrawIdx, @alignCast(@alignOf(c.ImDrawIdx), self.index_buffers[frame_index].mapped_memory));

        var n: usize = 0;
        while (n < draw_data.CmdListsCount) : (n += 1) {
            const cmd_list: *c.ImDrawList = draw_data.CmdLists[n];
            @memcpy(
                @ptrCast([*]align(4) u8, @alignCast(4, vtx_dst)),
                @ptrCast([*]align(4) const u8, @alignCast(4, cmd_list.VtxBuffer.Data)),
                @intCast(usize, cmd_list.VtxBuffer.Size) * @sizeOf(c.ImDrawVert),
            );
            @memcpy(
                @ptrCast([*]align(2) u8, @alignCast(2, idx_dst)),
                @ptrCast([*]align(2) const u8, @alignCast(2, cmd_list.IdxBuffer.Data)),
                @intCast(usize, cmd_list.IdxBuffer.Size) * @sizeOf(c.ImDrawIdx),
            );
            vtx_dst += @intCast(usize, cmd_list.VtxBuffer.Size);
            idx_dst += @intCast(usize, cmd_list.IdxBuffer.Size);
        }

        self.vertex_buffers[frame_index].flush();
        self.index_buffers[frame_index].flush();
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

        self.render_pass.init(&rg.global_render_graph.final_swapchain, color_attachment[0..]);
    }

    fn createGraphicsPipeline(self: *UIVulkanContext) void {
        const push_constant_range: vk.PushConstantRange = .{
            .stage_flags = .{ .vertex_bit = true },
            .offset = 0,
            .size = @sizeOf(PushConstBlock),
        };

        const pipeline_layout_create_info: vk.PipelineLayoutCreateInfo = .{
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast([*]const vk.DescriptorSetLayout, &self.descriptor_set_layout),
            .push_constant_range_count = 1,
            .p_push_constant_ranges = @ptrCast([*]const vk.PushConstantRange, &push_constant_range),
            .flags = .{},
        };

        self.pipeline_layout = vkfn.d.createPipelineLayout(vkctxt.device, pipeline_layout_create_info, null) catch |err| {
            printVulkanError("Can't create pipeline layout", err);
            return;
        };

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

        const vertex_input_bindings: vk.VertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(c.ImDrawVert),
            .input_rate = .vertex,
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

        const vertex_input_state: vk.PipelineVertexInputStateCreateInfo = .{
            .vertex_binding_description_count = 1,
            .p_vertex_binding_descriptions = @ptrCast([*]const vk.VertexInputBindingDescription, &vertex_input_bindings),
            .vertex_attribute_description_count = 3,
            .p_vertex_attribute_descriptions = @ptrCast([*]const vk.VertexInputAttributeDescription, &vertex_input_attributes),
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
            .module = self.frag_shader.vk_ref,
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
            printVulkanError("Can't create graphics pipeline for ui", err);
            return;
        };
    }

    fn initFonts(self: *UIVulkanContext) void {
        var io: c.ImGuiIO = c.igGetIO().*;

        var scale: [2]f32 = undefined;
        c.glfwGetWindowContentScale(self.parent.app.window, &scale[0], &scale[1]);

        _ = c.ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(io.Fonts, @ptrCast([*c]const u8, &c.FiraSans_compressed_data_base85), 13.0 * scale[1], null, null);

        var font_data: [*c]u8 = undefined;
        var tex_dim: [2]c_int = undefined;
        c.ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, @ptrCast([*c][*c]u8, &font_data), &tex_dim[0], &tex_dim[1], null);

        const tex_size: usize = @intCast(usize, 4 * tex_dim[0] * tex_dim[1]);

        const buffer_info: vk.BufferCreateInfo = .{
            .size = tex_size,
            .usage = .{
                .transfer_src_bit = true,
            },
            .sharing_mode = .exclusive,
            .flags = .{},
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        var staging_buffer: vk.Buffer = vkfn.d.createBuffer(vkctxt.device, buffer_info, null) catch |err| {
            printVulkanError("Can't crete buffer for font texture", err);
            return;
        };
        defer vkfn.d.destroyBuffer(vkctxt.device, staging_buffer, null);

        var mem_req: vk.MemoryRequirements = vkfn.d.getBufferMemoryRequirements(vkctxt.device, staging_buffer);

        const alloc_info: vk.MemoryAllocateInfo = .{
            .allocation_size = mem_req.size,
            .memory_type_index = vkctxt.getMemoryType(mem_req.memory_type_bits, .{ .host_visible_bit = true, .host_coherent_bit = true }),
        };

        var staging_buffer_memory: vk.DeviceMemory = vkfn.d.allocateMemory(vkctxt.device, alloc_info, null) catch |err| {
            printVulkanError("Can't allocate buffer for font texture", err);
            return;
        };
        defer vkfn.d.freeMemory(vkctxt.device, staging_buffer_memory, null);

        vkfn.d.bindBufferMemory(vkctxt.device, staging_buffer, staging_buffer_memory, 0) catch |err| {
            printVulkanError("Can't bind buffer memory for font texture", err);
            return;
        };
        var mapped_memory: *anyopaque = vkfn.d.mapMemory(vkctxt.device, staging_buffer_memory, 0, tex_size, .{}) catch |err| {
            printVulkanError("Can't map memory for font texture", err);
            return;
        } orelse return;
        @memcpy(@ptrCast([*]u8, mapped_memory), font_data, tex_size);
        vkfn.d.unmapMemory(vkctxt.device, staging_buffer_memory);

        self.font_texture.init("Font Texture", @intCast(u32, tex_dim[0]), @intCast(u32, tex_dim[1]), .r8g8b8a8_unorm, vkctxt.allocator);
        self.font_texture.alloc();

        var scb: SingleCommandBuffer = SingleCommandBuffer.allocate(&rg.global_render_graph.command_pool) catch unreachable;
        scb.command_buffer.beginSingleTimeCommands();

        self.font_texture.transitionImageLayout(scb.command_buffer.vk_ref, .@"undefined", .transfer_dst_optimal);

        const region: vk.BufferImageCopy = .{
            .buffer_offset = 0,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .base_array_layer = 0,
                .layer_count = 1,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = .{
                .width = @intCast(u32, tex_dim[0]),
                .height = @intCast(u32, tex_dim[1]),
                .depth = 1,
            },
        };

        vkfn.d.cmdCopyBufferToImage(scb.command_buffer.vk_ref, staging_buffer, self.font_texture.image, .transfer_dst_optimal, 1, @ptrCast([*]const vk.BufferImageCopy, &region));

        self.font_texture.transitionImageLayout(scb.command_buffer.vk_ref, .transfer_dst_optimal, .shader_read_only_optimal);

        scb.command_buffer.endSingleTimeCommands();
        scb.submit(vkctxt.graphics_queue);

        const pool_size: vk.DescriptorPoolSize = .{
            .type = .combined_image_sampler,
            .descriptor_count = 1,
        };

        const descriptor_pool_info: vk.DescriptorPoolCreateInfo = .{
            .pool_size_count = 1,
            .p_pool_sizes = @ptrCast([*]const vk.DescriptorPoolSize, &pool_size),
            .max_sets = 2,
            .flags = .{},
        };

        self.descriptor_pool = vkfn.d.createDescriptorPool(vkctxt.device, descriptor_pool_info, null) catch |err| {
            printVulkanError("Can't create descriptor pool for ui", err);
            return;
        };

        const set_layout_bindings: vk.DescriptorSetLayoutBinding = .{
            .stage_flags = .{ .fragment_bit = true },
            .binding = 0,
            .descriptor_count = 1,
            .descriptor_type = .combined_image_sampler,
            .p_immutable_samplers = undefined,
        };

        const set_layout_create_info: vk.DescriptorSetLayoutCreateInfo = .{
            .binding_count = 1,
            .p_bindings = @ptrCast([*]const vk.DescriptorSetLayoutBinding, &set_layout_bindings),
            .flags = .{},
        };

        self.descriptor_set_layout = vkfn.d.createDescriptorSetLayout(vkctxt.device, set_layout_create_info, null) catch |err| {
            printVulkanError("Can't create descriptor set layout for ui", err);
            return;
        };

        const descriptor_set_allocate_info: vk.DescriptorSetAllocateInfo = .{
            .descriptor_pool = self.descriptor_pool,
            .p_set_layouts = @ptrCast([*]const vk.DescriptorSetLayout, &self.descriptor_set_layout),
            .descriptor_set_count = 1,
        };

        vkfn.d.allocateDescriptorSets(vkctxt.device, descriptor_set_allocate_info, @ptrCast([*]vk.DescriptorSet, &self.descriptor_set)) catch |err| {
            printVulkanError("Can't allocate descriptor set for ui", err);
            return;
        };

        const font_descriptor_image_info: vk.DescriptorImageInfo = .{
            .sampler = self.font_texture.sampler,
            .image_view = self.font_texture.view,
            .image_layout = .shader_read_only_optimal,
        };

        const write_descriptor_set: vk.WriteDescriptorSet = .{
            .dst_set = self.descriptor_set,
            .descriptor_type = .combined_image_sampler,
            .dst_binding = 0,
            .p_image_info = @ptrCast([*]const vk.DescriptorImageInfo, &font_descriptor_image_info),
            .descriptor_count = 1,
            .dst_array_element = 0,
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        };

        vkfn.d.updateDescriptorSets(vkctxt.device, 1, @ptrCast([*]const vk.WriteDescriptorSet, &write_descriptor_set), 0, undefined);
    }

    fn initResources(self: *UIVulkanContext) void {
        self.initFonts();

        const pipeline_cache_create_info: vk.PipelineCacheCreateInfo = .{
            .flags = .{},
            .initial_data_size = 0,
            .p_initial_data = undefined,
        };

        self.pipeline_cache = vkfn.d.createPipelineCache(vkctxt.device, pipeline_cache_create_info, null) catch |err| {
            printVulkanError("Can't create pipeline cache", err);
            return;
        };

        const ui_vert = @embedFile("ui.vert");
        const ui_frag = @embedFile("ui.frag");
        self.vert_shader = ShaderModule.load(ui_vert, .vertex);
        self.frag_shader = ShaderModule.load(ui_frag, .fragment);

        self.createRenderPass();
        self.createGraphicsPipeline();

        const buffer_count: u32 = rg.global_render_graph.final_swapchain.image_count;

        self.vertex_buffers = vkctxt.allocator.alloc(Buffer, buffer_count) catch unreachable;
        self.index_buffers = vkctxt.allocator.alloc(Buffer, buffer_count) catch unreachable;

        self.vertex_buffer_counts = vkctxt.allocator.alloc(usize, buffer_count) catch unreachable;
        self.index_buffer_counts = vkctxt.allocator.alloc(usize, buffer_count) catch unreachable;

        for (self.vertex_buffers) |*buffer| {
            buffer.* = undefined;
            buffer.buffer = .null_handle;
        }
        for (self.index_buffers) |*buffer| {
            buffer.* = undefined;
            buffer.buffer = .null_handle;
        }

        for (self.vertex_buffer_counts) |*count|
            count.* = 0;
        for (self.index_buffer_counts) |*count|
            count.* = 0;
    }
};
