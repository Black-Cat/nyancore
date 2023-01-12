const std = @import("std");

const Image = @import("../image/image.zig").Image;
const Sampler = @import("../vulkan_wrapper/sampler.zig").Sampler;

pub const MaterialInfo = struct {
    allocator: std.mem.Allocator,

    name: []const u8 = "NO MATERIAL NAME",
    double_sided: bool = false,

    images: []Image,
    samplers: []Sampler,
};
