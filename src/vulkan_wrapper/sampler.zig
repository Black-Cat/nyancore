const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const Sampler = struct {
    vk_ref: vk.Sampler,

    pub fn init(self: *Sampler) void {
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

        self.vk_ref = vkfn.d.createSampler(vkctxt.device, sampler_info, null) catch |err| {
            printVulkanError("Can't create sampler", err);
            return;
        };
    }

    pub fn deinit(self: *Sampler) void {
        vkfn.d.destroySampler(vkctxt.device, self.vk_ref, null);
    }
};
