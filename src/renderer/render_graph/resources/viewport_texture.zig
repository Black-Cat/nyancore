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

    pub fn init(self: *ViewportTexture, name: []const u8, in_flight: u32, width: u32, height: u32, allocator: *std.mem.Allocator) void {
        self.width = width;
        self.height = height;

        self.rg_resource.init(name, allocator);

        self.allocator = allocator;
        self.textures = allocator.alloc(Texture, in_flight) catch unreachable;
    }

    pub fn deinit(self: *ViewportTexture) void {
        self.allocator.free(self.textures);
    }

    pub fn alloc(self: *ViewportTexture) void {
        for (self.textures) |*tex| {
            tex.init(self.rg_resource.name, self.width, self.height, self.allocator);
            tex.alloc();
        }
    }

    pub fn destroy(self: *ViewportTexture) void {
        for (self.textures) |*tex|
            tex.destroy();
    }

    pub fn resize(self: *ViewportTexture, rg: *RenderGraph) void {
        rg.changeResourceBetweenFrames(&self.rg_resource, resizeBetweenFrames);
    }

    fn resizeBetweenFrames(res: *RGResource) void {
        const self: *ViewportTexture = @fieldParentPtr(ViewportTexture, "rg_resource", res);

        self.destroy();
        self.alloc();
    }
};
