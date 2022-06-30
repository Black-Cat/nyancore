const vk = @import("../../../vk.zig");
const std = @import("std");
const rg = @import("../render_graph.zig");

const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../../../vulkan_wrapper/vulkan_functions.zig");

const printError = @import("../../../application/print_error.zig").printError;
const printVulkanError = @import("../../../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const RGResource = @import("../render_graph_resource.zig").RGResource;
const RenderGraph = @import("../render_graph.zig").RenderGraph;
const SingleCommandBuffer = @import("../../../vulkan_wrapper/single_command_buffer.zig").SingleCommandBuffer;

pub const Texture = struct {
    rg_resource: RGResource,

    size: [2]u32,
    image: vk.Image,
    memory: vk.DeviceMemory,
    view: vk.ImageView,
    sampler: vk.Sampler,
    image_format: vk.Format = .r8g8b8a8_unorm,
    image_create_info: vk.ImageCreateInfo,
    image_layout: vk.ImageLayout,

    pub fn init(self: *Texture, name: []const u8, width: u32, height: u32, image_format: vk.Format, allocator: std.mem.Allocator) void {
        self.rg_resource.init(name, allocator);

        self.size[0] = width;
        self.size[1] = height;
        self.image_format = image_format;

        self.image_create_info = .{
            .image_type = .@"2d",
            .format = self.image_format,
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

        self.image_layout = .shader_read_only_optimal;
    }

    pub fn deinit(self: *Texture) void {
        self.rg_resource.deinit();
    }

    pub fn alloc(self: *Texture) void {
        self.image = vkfn.d.createImage(vkctxt.device, self.image_create_info, null) catch |err| {
            printVulkanError("Can't create texture", err);
            return;
        };

        var mem_req: vk.MemoryRequirements = vkfn.d.getImageMemoryRequirements(vkctxt.device, self.image);

        const mem_alloc_info: vk.MemoryAllocateInfo = .{
            .allocation_size = mem_req.size,
            .memory_type_index = vkctxt.getMemoryType(mem_req.memory_type_bits, .{ .device_local_bit = true }),
        };
        self.memory = vkfn.d.allocateMemory(vkctxt.device, mem_alloc_info, null) catch |err| {
            printVulkanError("Can't allocate texture memory", err);
            return;
        };

        vkfn.d.bindImageMemory(vkctxt.device, self.image, self.memory, 0) catch |err| {
            printVulkanError("Can't bind texture memory", err);
            return;
        };

        const view_info: vk.ImageViewCreateInfo = .{
            .image = self.image,
            .view_type = .@"2d",
            .format = self.image_format,
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
        self.view = vkfn.d.createImageView(vkctxt.device, view_info, null) catch |err| {
            printVulkanError("Can't create image view", err);
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

        self.sampler = vkfn.d.createSampler(vkctxt.device, sampler_info, null) catch |err| {
            printVulkanError("Can't create sampler for ui texture", err);
            return;
        };

        if (self.image_layout != .@"undefined") {
            var scb: SingleCommandBuffer = SingleCommandBuffer.allocate(&rg.global_render_graph.command_pool) catch unreachable;
            scb.command_buffer.beginSingleTimeCommands();
            self.transitionImageLayout(scb.command_buffer.vk_ref, .@"undefined", self.image_layout);
            scb.command_buffer.endSingleTimeCommands();
            scb.submit(vkctxt.graphics_queue);
        }
    }

    pub fn destroy(self: *Texture) void {
        vkfn.d.destroySampler(vkctxt.device, self.sampler, null);
        vkfn.d.destroyImage(vkctxt.device, self.image, null);
        vkfn.d.destroyImageView(vkctxt.device, self.view, null);
        vkfn.d.freeMemory(vkctxt.device, self.memory, null);
    }

    pub fn transitionImageLayout(self: *Texture, command_buffer: vk.CommandBuffer, old_layout: vk.ImageLayout, new_layout: vk.ImageLayout) void {
        var barrier: vk.ImageMemoryBarrier = .{
            .old_layout = old_layout,
            .new_layout = new_layout,

            .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,

            .image = self.image,
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
        } else if (old_layout == .@"undefined" and new_layout == .shader_read_only_optimal) {
            barrier.src_access_mask = .{};
            barrier.dst_access_mask = .{ .shader_read_bit = true };

            source_stage = .{ .top_of_pipe_bit = true };
            destination_stage = .{ .fragment_shader_bit = true };
        } else {
            @panic("Not supported image layouts for transfer");
        }

        vkfn.d.cmdPipelineBarrier(command_buffer, source_stage, destination_stage, .{}, 0, undefined, 0, undefined, 1, @ptrCast([*]const vk.ImageMemoryBarrier, &barrier));
    }
};
