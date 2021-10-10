const vk = @import("../../../vk.zig");
const std = @import("std");

usingnamespace @import("../../../vulkan_wrapper/vulkan_wrapper.zig");

const printError = @import("../../../application/print_error.zig").printError;
const RGResource = @import("../render_graph_resource.zig").RGResource;

pub const Texture = struct {
    rg_resource: RGResource,

    size: [2]u32,
    image: vk.Image,
    memory: vk.DeviceMemory,
    view: vk.ImageView,
    sampler: vk.Sampler,

    pub fn init(self: *Texture, name: []const u8, width: u32, height: u32, allocator: *std.mem.Allocator) void {
        self.rg_resource.init(name, allocator);

        self.size[0] = width;
        self.size[1] = height;
    }

    pub fn alloc(self: *Texture) void {
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
