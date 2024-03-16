const vk = @import("../../../vk.zig");
const std = @import("std");

const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");

const printError = @import("../../../application/print_error.zig").printError;
const RGResource = @import("../render_graph_resource.zig").RGResource;
const RenderGraph = @import("../render_graph.zig").RenderGraph;

const RenderPass = @import("../../../vulkan_wrapper/render_pass.zig").RenderPass;
const Texture = @import("texture.zig").Texture;

pub const ViewportTexture = struct {
    rg_resource: RGResource,

    allocator: std.mem.Allocator,
    textures: []Texture,

    extent: vk.Extent2D,

    // Used for resizing
    new_width: u32,
    new_height: u32,

    image_format: vk.Format,
    usage: vk.ImageUsageFlags,
    image_layout: vk.ImageLayout,

    render_passes: std.ArrayList(*RenderPass),

    pub fn init(self: *ViewportTexture, name: []const u8, in_flight: u32, width: u32, height: u32, image_format: vk.Format, allocator: std.mem.Allocator) void {
        self.extent = .{
            .width = width,
            .height = height,
        };
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
        self.render_passes = std.ArrayList(*RenderPass).init(vkctxt.allocator);
    }

    pub fn deinit(self: *ViewportTexture) void {
        self.render_passes.deinit();
        self.allocator.free(self.textures);
    }

    pub fn alloc(self: *ViewportTexture) void {
        for (self.textures) |*tex| {
            tex.init(self.rg_resource.name, self.extent.width, self.extent.height, self.image_format, self.allocator);
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

        self.extent = .{
            .width = self.new_width,
            .height = self.new_height,
        };

        self.destroy();
        self.alloc();

        for (self.render_passes.items) |rp|
            rp.target_recreated_callback(rp);
    }

    fn deleteBetweenFrames(res: *RGResource) void {
        const self: *ViewportTexture = @fieldParentPtr(ViewportTexture, "rg_resource", res);
        self.destroy();
        self.deinit();
    }
};
