const std = @import("std");

const Swapchain = @import("resources/swapchain.zig").Swapchain;

const RGPass = @import("render_graph_pass.zig").RGPass;
const PassList = std.ArrayList(*RGPass);
const RGResource = @import("render_graph_resource.zig").RGResource;
const ResourceList = std.ArrayList(*RGResource);

pub var global_render_graph: RenderGraph = undefined;

pub const RenderGraph = struct {
    final_swapchain: Swapchain,
    frame_index: u32,

    passes: PassList,
    resources: ResourceList,
};
