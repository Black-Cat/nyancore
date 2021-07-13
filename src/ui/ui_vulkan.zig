const c = @import("../c.zig");
const vk = @import("../vk.zig");
const shader_util = @import("../shaders/shader_util.zig");

usingnamespace @cImport({
    @cInclude("fira_sans_regular.h");
});

usingnamespace @import("../vulkan_wrapper/vulkan_wrapper.zig");

const UI = @import("ui.zig").UI;

const printError = @import("../application/print_error.zig").printError;

const PushConstBlock = packed struct {
    scale_translate: [4]f32,
};

const Texture = struct {
    size: [2]u32,
    image: vk.Image,
    memory: vk.DeviceMemory,
    view: vk.ImageView,
    sampler: vk.Sampler,

    pub fn create(self: *Texture, width: u32, height: u32) void {
        self.size[0] = width;
        self.size[1] = height;

        const image_info: vk.ImageCreateInfo = .{
            .image_type = .@"2d",
            .format = .r8g8b8a8_unorm,
            .extent = .{
                .width = self.size[0],
                .height = self.size[1],
                .depth = 1,
            },
            .mip_levels = 1,
            .array_layers = 1,
            .samples = .{
                .@"1_bit" = true,
            },
            .tiling = .optimal,
            .usage = .{
                .sampled_bit = true,
                .color_attachment_bit = true,
                .transfer_dst_bit = true,
            },
            .sharing_mode = .exclusive,
            .initial_layout = .@"undefined",
            .flags = .{},
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        self.image = vkd.createImage(vkc.device, image_info, null) catch |err| {
            printVulkanError("Can't create texture for ui", err, vkc.allocator);
            return;
        };

        var mem_req: vk.MemoryRequirements = vkd.getImageMemoryRequirements(vkc.device, self.image);

        const mem_alloc_info: vk.MemoryAllocateInfo = .{
            .allocation_size = mem_req.size,
            .memory_type_index = vkc.getMemoryType(mem_req.memory_type_bits, .{ .device_local_bit = true }),
        };
        self.memory = vkd.allocateMemory(vkc.device, mem_alloc_info, null) catch |err| {
            printVulkanError("Can't allocate texture memory for ui", err, vkc.allocator);
            return;
        };

        vkd.bindImageMemory(vkc.device, self.image, self.memory, 0) catch |err| {
            printVulkanError("Can't bind texture memory for ui", err, vkc.allocator);
            return;
        };

        const view_info: vk.ImageViewCreateInfo = .{
            .image = self.image,
            .view_type = .@"2d",
            .format = .r8g8b8a8_unorm,
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .level_count = 1,
                .layer_count = 1,
                .base_mip_level = 0,
                .base_array_layer = 0,
            },
            .flags = .{},
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
        };
        self.view = vkd.createImageView(vkc.device, view_info, null) catch |err| {
            printVulkanError("Can't create image view for ui", err, vkc.allocator);
            return;
        };

        const sampler_info: vk.SamplerCreateInfo = .{
            .mag_filter = .linear,
            .min_filter = .linear,
            .mipmap_mode = .linear,
            .address_mode_u = .clamp_to_edge,
            .address_mode_v = .clamp_to_edge,
            .address_mode_w = .clamp_to_edge,
            .border_color = .float_opaque_white,
            .flags = .{},
            .mip_lod_bias = 0,
            .anisotropy_enable = 0,
            .max_anisotropy = 0,
            .compare_enable = 0,
            .compare_op = .never,
            .min_lod = 0,
            .max_lod = 0,
            .unnormalized_coordinates = 0,
        };

        self.sampler = vkd.createSampler(vkc.device, sampler_info, null) catch |err| {
            printVulkanError("Can't create sampler for ui texture", err, vkc.allocator);
            return;
        };
    }

    pub fn destroy(self: *Texture) void {
        vkd.destroySampler(vkc.device, self.sampler, null);
        vkd.destroyImage(vkc.device, self.image, null);
        vkd.destroyImageView(vkc.device, self.view, null);
        vkd.freeMemory(vkc.device, self.memory, null);
    }
};

pub const UIVulkanContext = struct {
    parent: *UI,
    font_texture: Texture,
    command_pool: vk.CommandPool,

    descriptor_pool: vk.DescriptorPool,
    descriptor_set_layout: vk.DescriptorSetLayout,
    descriptor_set: vk.DescriptorSet,

    pipeline_cache: vk.PipelineCache,

    frag_shader: vk.ShaderModule,
    vert_shader: vk.ShaderModule,

    pub fn init(self: *UIVulkanContext, parent: *UI) void {
        self.parent = parent;

        self.initResources();
        //self.createGraphicsPipeline();
    }
    pub fn deinit(self: *UIVulkanContext) void {
        vkd.destroyShaderModule(vkc.device, self.vert_shader, null);
        vkd.destroyShaderModule(vkc.device, self.frag_shader, null);

        vkd.destroyPipelineCache(vkc.device, self.pipeline_cache, null);

        vkd.destroyDescriptorSetLayout(vkc.device, self.descriptor_set_layout, null);
        vkd.destroyDescriptorPool(vkc.device, self.descriptor_pool, null);

        vkd.destroyCommandPool(vkc.device, self.command_pool, null);
        self.font_texture.destroy();
    }
    pub fn render(self: *UIVulkanContext) void {}

    fn createGraphicsPipeline(self: *UIVulkanContext) void {
        const push_constant_range: vk.PushConstantRange = .{
            .stage_flags = .vertex_bit,
            .offset = 0,
            .size = @sizeOf(PushConstBlock),
        };

        //const pipeline_create_info: vk.PipelineLayoutCreateInfo = .{
        //.set_layout_count = 1,
        //.p_set_layouts = &push_constant_range,
        //.push_constant_range_count = 1,
        //.p_push_constant_ranges = &push_constant_range,
        //};
    }

    fn beginSingleTimeCommands(self: *UIVulkanContext) vk.CommandBuffer {
        const alloc_info: vk.CommandBufferAllocateInfo = .{
            .level = .primary,
            .command_pool = self.command_pool,
            .command_buffer_count = 1,
        };

        var command_buffer: vk.CommandBuffer = undefined;
        vkd.allocateCommandBuffers(vkc.device, alloc_info, @ptrCast([*]vk.CommandBuffer, &command_buffer)) catch |err| {
            printVulkanError("Can't allocate command buffer for ui", err, vkc.allocator);
        };

        const begin_info: vk.CommandBufferBeginInfo = .{
            .flags = .{
                .one_time_submit_bit = true,
            },
            .p_inheritance_info = undefined,
        };

        vkd.beginCommandBuffer(command_buffer, begin_info) catch |err| {
            printVulkanError("Can't begin command buffers for ui", err, vkc.allocator);
        };

        return command_buffer;
    }

    fn endSingleTimeCommands(self: *UIVulkanContext, command_buffer: vk.CommandBuffer) void {
        vkd.endCommandBuffer(command_buffer) catch |err| {
            printVulkanError("Can't end command buffer for ui", err, vkc.allocator);
            return;
        };

        const submit_info: vk.SubmitInfo = .{
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &command_buffer),
            .wait_semaphore_count = 0,
            .p_wait_semaphores = undefined,
            .p_wait_dst_stage_mask = undefined,
            .signal_semaphore_count = 0,
            .p_signal_semaphores = undefined,
        };

        vkd.queueSubmit(vkc.graphics_queue, 1, @ptrCast([*]const vk.SubmitInfo, &submit_info), .null_handle) catch |err| {
            printVulkanError("Can't submit queue for ui", err, vkc.allocator);
        };
        vkd.queueWaitIdle(vkc.graphics_queue) catch |err| {
            printVulkanError("Can't wait for queue for ui", err, vkc.allocator);
        };

        vkd.freeCommandBuffers(vkc.device, self.command_pool, 1, @ptrCast([*]const vk.CommandBuffer, &command_buffer));
    }

    fn transitionImageLayout(self: *UIVulkanContext, command_buffer: *vk.CommandBuffer, image: vk.Image, format: vk.Format, old_layout: vk.ImageLayout, new_layout: vk.ImageLayout) void {
        var barrier: vk.ImageMemoryBarrier = .{
            .old_layout = old_layout,
            .new_layout = new_layout,

            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,

            .image = image,
            .subresource_range = .{
                .aspect_mask = .{
                    .color_bit = true,
                },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },

            .src_access_mask = undefined,
            .dst_access_mask = undefined,
        };

        var source_stage: vk.PipelineStageFlags = undefined;
        var destination_stage: vk.PipelineStageFlags = undefined;

        if (old_layout == .@"undefined" and new_layout == .transfer_dst_optimal) {
            barrier.src_access_mask = .{};
            barrier.dst_access_mask = .{ .transfer_write_bit = true };

            source_stage = .{ .top_of_pipe_bit = true };
            destination_stage = .{ .transfer_bit = true };
        } else if (old_layout == .transfer_dst_optimal and new_layout == .shader_read_only_optimal) {
            barrier.src_access_mask = .{ .transfer_write_bit = true };
            barrier.dst_access_mask = .{ .shader_read_bit = true };

            source_stage = .{ .transfer_bit = true };
            destination_stage = .{ .fragment_shader_bit = true };
        } else {
            @panic("Not supported image layouts for transfer");
        }

        vkd.cmdPipelineBarrier(command_buffer.*, source_stage, destination_stage, .{}, 0, undefined, 0, undefined, 1, @ptrCast([*]const vk.ImageMemoryBarrier, &barrier));
    }

    fn loadShader(self: *UIVulkanContext, shader_code: [*:0]const u8, stage: shader_util.ShaderStage) vk.ShaderModule {
        const shader: shader_util.CompiledShader = shader_util.compileShader(shader_code, stage);

        const module_create_info: vk.ShaderModuleCreateInfo = .{
            .code_size = shader.size,
            .p_code = shader.pcode,
            .flags = .{},
        };

        var shader_module: vk.ShaderModule = vkd.createShaderModule(vkc.device, module_create_info, null) catch |err| {
            printVulkanError("Can't create shader module for ui", err, vkc.allocator);
            @panic("Can't create shader module for ui");
        };

        return shader_module;
    }

    fn initFonts(self: *UIVulkanContext) void {
        var io: c.ImGuiIO = c.igGetIO().*;

        var scale: [2]f32 = undefined;
        c.glfwGetWindowContentScale(self.parent.app.window, &scale[0], &scale[1]);

        _ = c.ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(io.Fonts, @ptrCast([*c]const u8, &FiraSans_compressed_data_base85), 13.0 * scale[1], null, null);

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

        var staging_buffer: vk.Buffer = vkd.createBuffer(vkc.device, buffer_info, null) catch |err| {
            printVulkanError("Can't crete buffer for font texture", err, vkc.allocator);
            return;
        };
        defer vkd.destroyBuffer(vkc.device, staging_buffer, null);

        var mem_req: vk.MemoryRequirements = vkd.getBufferMemoryRequirements(vkc.device, staging_buffer);

        const alloc_info: vk.MemoryAllocateInfo = .{
            .allocation_size = mem_req.size,
            .memory_type_index = vkc.getMemoryType(mem_req.memory_type_bits, .{ .host_visible_bit = true, .host_coherent_bit = true }),
        };

        var staging_buffer_memory: vk.DeviceMemory = vkd.allocateMemory(vkc.device, alloc_info, null) catch |err| {
            printVulkanError("Can't allocate buffer for font texture", err, vkc.allocator);
            return;
        };
        defer vkd.freeMemory(vkc.device, staging_buffer_memory, null);

        vkd.bindBufferMemory(vkc.device, staging_buffer, staging_buffer_memory, 0) catch |err| {
            printVulkanError("Can't bind buffer memory for font texture", err, vkc.allocator);
            return;
        };
        var mapped_memory: *c_void = vkd.mapMemory(vkc.device, staging_buffer_memory, 0, tex_size, .{}) catch |err| {
            printVulkanError("Can't map memory for font texture", err, vkc.allocator);
            return;
        } orelse return;
        @memcpy(@ptrCast([*]u8, mapped_memory), font_data, tex_size);
        vkd.unmapMemory(vkc.device, staging_buffer_memory);

        self.font_texture.create(@intCast(u32, tex_dim[0]), @intCast(u32, tex_dim[1]));

        var command_buffer: vk.CommandBuffer = self.beginSingleTimeCommands();

        self.transitionImageLayout(&command_buffer, self.font_texture.image, .r8g8b8a8_unorm, .@"undefined", .transfer_dst_optimal);

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

        vkd.cmdCopyBufferToImage(command_buffer, staging_buffer, self.font_texture.image, .transfer_dst_optimal, 1, @ptrCast([*]const vk.BufferImageCopy, &region));

        self.transitionImageLayout(&command_buffer, self.font_texture.image, .r8g8b8a8_unorm, .transfer_dst_optimal, .shader_read_only_optimal);

        self.endSingleTimeCommands(command_buffer);

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

        self.descriptor_pool = vkd.createDescriptorPool(vkc.device, descriptor_pool_info, null) catch |err| {
            printVulkanError("Can't create descriptor pool for ui", err, vkc.allocator);
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

        self.descriptor_set_layout = vkd.createDescriptorSetLayout(vkc.device, set_layout_create_info, null) catch |err| {
            printVulkanError("Can't create descriptor set layout for ui", err, vkc.allocator);
            return;
        };

        const descriptor_set_allocate_info: vk.DescriptorSetAllocateInfo = .{
            .descriptor_pool = self.descriptor_pool,
            .p_set_layouts = @ptrCast([*]const vk.DescriptorSetLayout, &self.descriptor_set_layout),
            .descriptor_set_count = 1,
        };

        vkd.allocateDescriptorSets(vkc.device, descriptor_set_allocate_info, @ptrCast([*]vk.DescriptorSet, &self.descriptor_set)) catch |err| {
            printVulkanError("Can't allocate descriptor set for ui", err, vkc.allocator);
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

        vkd.updateDescriptorSets(vkc.device, 1, @ptrCast([*]const vk.WriteDescriptorSet, &write_descriptor_set), 0, undefined);

        const pipeline_cache_create_info: vk.PipelineCacheCreateInfo = .{
            .flags = .{},
            .initial_data_size = 0,
            .p_initial_data = undefined,
        };

        self.pipeline_cache = vkd.createPipelineCache(vkc.device, pipeline_cache_create_info, null) catch |err| {
            printVulkanError("Can't create pipeline cache", err, vkc.allocator);
            return;
        };

        const ui_vert = @embedFile("ui.vert");
        const ui_frag = @embedFile("ui.frag");
        var testa: [*:0]const u8 = ui_vert;
        self.vert_shader = self.loadShader(testa, .vertex);
        self.frag_shader = self.loadShader(ui_frag, .fragment);
    }

    fn initResources(self: *UIVulkanContext) void {
        const pool_info: vk.CommandPoolCreateInfo = .{
            .queue_family_index = vkc.family_indices.graphics_family,
            .flags = .{
                .reset_command_buffer_bit = true,
            },
        };

        self.command_pool = vkd.createCommandPool(vkc.device, pool_info, null) catch |err| {
            printVulkanError("Can't create command pool for ui", err, vkc.allocator);
            return;
        };

        self.initFonts();
    }
};
