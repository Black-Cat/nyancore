const std = @import("std");

usingnamespace @import("resources/resources.zig");
usingnamespace @import("../../vulkan_wrapper/vulkan_wrapper.zig");

const RGPass = @import("render_graph_pass.zig").RGPass;
const PassList = std.ArrayList(*RGPass);
const RGResource = @import("render_graph_resource.zig").RGResource;
const ResourceList = std.ArrayList(*RGResource);

pub var global_render_graph: RenderGraph = undefined;

pub const RenderGraph = struct {
    pub const ResourceChangeFn = struct {
        res: *RGResource,
        change_fn: fn (res: *RGResource) void,
    };

    final_swapchain: Swapchain,
    needs_rebuilding: bool,

    frame_index: u32,
    image_index: u32,
    in_flight: u32,

    passes: PassList,
    resources: ResourceList,

    resource_changes: std.ArrayList(ResourceChangeFn),

    textures: std.ArrayList(*Texture),
    viewport_textures: std.ArrayList(*ViewportTexture),

    pub fn init(self: *RenderGraph, in_flight: u32, allocator: *std.mem.Allocator) void {
        self.passes = PassList.init(allocator);
        self.resources = ResourceList.init(allocator);

        self.resource_changes = std.ArrayList(ResourceChangeFn).init(allocator);

        self.textures = std.ArrayList(*Texture).init(allocator);
        self.viewport_textures = std.ArrayList(*ViewportTexture).init(allocator);

        self.frame_index = 0;
        self.image_index = 0;
        self.in_flight = in_flight;
        self.needs_rebuilding = false;
    }

    pub fn deinit(self: *RenderGraph) void {
        self.passes.deinit();
        self.resources.deinit();
    }

    pub fn addTexture(self: *RenderGraph, tex: *Texture) void {
        self.textures.append(tex) catch unreachable;
        self.resources.append(&tex.rg_resource) catch unreachable;
    }

    pub fn addViewportTexture(self: *RenderGraph, tex: *ViewportTexture) void {
        self.viewport_textures.append(tex) catch unreachable;
        self.resources.append(&tex.rg_resource) catch unreachable;
    }

    pub fn removeTexture(self: *RenderGraph, tex: *Texture) void {}

    pub fn changeResourceBetweenFrames(self: *RenderGraph, res: *RGResource, change_fn: fn (res: *RGResource) void) void {
        const fn_cxt: ResourceChangeFn = .{
            .res = res,
            .change_fn = change_fn,
        };
        self.resource_changes.append(fn_cxt) catch unreachable;
    }

    pub fn executeResourceChanges(self: *RenderGraph) void {
        if (self.resource_changes.items.len == 0)
            return;

        vkd.deviceWaitIdle(vkc.device) catch |err| {
            printVulkanError("Can't wait for device idle in order to change resources", err, vkc.allocator);
            return;
        };

        for (self.resource_changes.items) |ctx|
            ctx.change_fn(ctx.res);

        self.resource_changes.clearRetainingCapacity();
    }
};
