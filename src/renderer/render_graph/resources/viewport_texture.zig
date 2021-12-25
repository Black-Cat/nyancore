const vk = @import("../../../vk.zig");
const std = @import("std");

usingnamespace @import("../../../vulkan_wrapper/vulkan_wrapper.zig");

const printError = @import("../../../application/print_error.zig").printError;
const RGResource = @import("../render_graph_resource.zig").RGResource;
const RenderGraph = @import("../render_graph.zig").RenderGraph;

const Texture = @import("texture.zig").Texture;

pub const ViewportTexture = struct {
    rg_resource: RGResource,

    allocator: *std.mem.Allocator,
    textures: []Texture,

    width: u32,
    height: u32,

    // Used for resizing
    new_width: u32,
    new_height: u32,

    image_format: vk.Format,
    usage: vk.ImageUsageFlags,
    image_layout: vk.ImageLayout,

    pub fn init(self: *ViewportTexture, name: []const u8, in_flight: u32, width: u32, height: u32, image_format: vk.Format, allocator: *std.mem.Allocator) void {
        self.width = width;
        self.height = height;
        self.image_format = image_format;

        self.rg_resource.init(name, allocator);

        self.allocator = allocator;
        self.textures = allocator.alloc(Texture, in_flight) catch unreachable;
        self.usage = .{
            .sampled_bit = true,
            .color_attachment_bit = true,
            .transfer_dst_bit = true,
        };
        self.image_layout = .shader_read_only_optimal;
    }

    pub fn deinit(self: *ViewportTexture) void {
        self.allocator.free(self.textures);
    }

    pub fn alloc(self: *ViewportTexture) void {
        for (self.textures) |*tex| {
            tex.init(self.rg_resource.name, self.width, self.height, self.image_format, self.allocator);
            tex.image_create_info.usage = self.usage;
            tex.image_layout = self.image_layout;
            tex.alloc();
        }
    }

    pub fn destroy(self: *ViewportTexture) void {
        for (self.textures) |*tex|
            tex.destroy();
    }

    pub fn resize(self: *ViewportTexture, rg: *RenderGraph, new_width: u32, new_height: u32) void {
        self.new_width = new_width;
        self.new_height = new_height;
        rg.changeResourceBetweenFrames(&self.rg_resource, resizeBetweenFrames);
    }

    fn resizeBetweenFrames(res: *RGResource) void {
        const self: *ViewportTexture = @fieldParentPtr(ViewportTexture, "rg_resource", res);

        self.width = self.new_width;
        self.height = self.new_height;

        self.destroy();
        self.alloc();
    }
};
