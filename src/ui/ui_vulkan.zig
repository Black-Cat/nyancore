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
const Pipeline = @import("../vulkan_wrapper/pipeline.zig").Pipeline;
const PipelineBuilder = @import("../vulkan_wrapper/pipeline_builder.zig").PipelineBuilder;
const PipelineCache = @import("../vulkan_wrapper/pipeline_cache.zig").PipelineCache;
const PipelineLayout = @import("../vulkan_wrapper/pipeline_layout.zig").PipelineLayout;
const Mesh = @import("../vulkan_wrapper/mesh.zig").Mesh;

const PushConstBlock = packed struct {
    scale_translate: [4]f32,
};

pub const UIVulkanContext = struct {
    parent: *UI,
    font_texture: Texture,

    descriptor_pool: vk.DescriptorPool,
    descriptor_set_layout: vk.DescriptorSetLayout,
    descriptor_set: vk.DescriptorSet,

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

        vkfn.d.cmdBindDescriptorSets(command_buffer.vk_ref, .graphics, self.pipeline_layout.vk_ref, 0, 1, @ptrCast([*]const vk.DescriptorSet, &self.descriptor_set), 0, undefined);
        vkfn.d.cmdBindPipeline(command_buffer.vk_ref, .graphics, self.pipeline.vk_ref);

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
        vkfn.d.cmdPushConstants(command_buffer.vk_ref, self.pipeline_layout.vk_ref, .{ .vertex_bit = true }, 0, @sizeOf(PushConstBlock), @ptrCast([*]const PushConstBlock, &push_const_block));

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
                    vkfn.d.cmdBindDescriptorSets(command_buffer.vk_ref, .graphics, self.pipeline_layout.vk_ref, 0, 1, descriptor_set, 0, undefined);
                }

                vkfn.d.cmdDrawIndexed(command_buffer.vk_ref, pcmd.ElemCount, 1, index_offset, vertex_offset, 0);
                index_offset += pcmd.ElemCount;

                // Return font descriptor
                if (pcmd.TextureId != null)
                    vkfn.d.cmdBindDescriptorSets(command_buffer.vk_ref, .graphics, self.pipeline_layout.vk_ref, 0, 1, @ptrCast([*]const vk.DescriptorSet, &self.descriptor_set), 0, undefined);
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
        const mesh: *Mesh = &self.meshes[frame_index];
        if (mesh.vertex_buffer.allocation_info.size < vertex_buffer_size)
            mesh.vertex_buffer.resize(vertex_buffer_size);

        if (mesh.index_buffer.allocation_info.size < index_buffer_size)
            mesh.index_buffer.resize(index_buffer_size);

        var vtx_dst: [*]c.ImDrawVert = @ptrCast([*]c.ImDrawVert, @alignCast(@alignOf(c.ImDrawVert), mesh.vertex_buffer.mapped_memory));
        var idx_dst: [*]c.ImDrawIdx = @ptrCast([*]c.ImDrawIdx, @alignCast(@alignOf(c.ImDrawIdx), mesh.index_buffer.mapped_memory));

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

        self.render_pass.init(&rg.global_render_graph.final_swapchain, color_attachment[0..]);
    }

    fn createGraphicsPipeline(self: *UIVulkanContext) void {
        const push_constant_range: vk.PushConstantRange = .{
            .stage_flags = .{ .vertex_bit = true },
            .offset = 0,
            .size = @sizeOf(PushConstBlock),
        };

        self.pipeline_layout = PipelineLayout.create(
            &[_]vk.DescriptorSetLayout{self.descriptor_set_layout},
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
            .depth_stencil_state = PipelineBuilder.buildDepthStencilState(),
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
