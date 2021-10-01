const std = @import("std");

const RGResource = @import("render_graph_resource.zig").RGResource;
const RenderGraph = @import("render_graph.zig").RenderGraph;

const ResourceList = std.ArrayList(*RGResource);

pub const RGPass = struct {
    const PassFunction = fn (render_pass: *RGPass, render_graph: *RenderGraph) void;

    name: []const u8,

    writes_to: ResourceList,
    reads_from: ResourceList,

    initFn: PassFunction,
    deinitFn: PassFunction,

    pub fn init(self: *RGPass, name: []const u8, allocator: *std.mem.Allocator, initFn: PassFunction, deinitFn: PassFunction) void {
        self.name = name;
        self.initFn = initFn;
        self.deinitFn = deinitFn;

        self.writes_to = ResourceList.init(allocator);
        self.reads_from = ResourceList.init(allocator);
    }

    pub fn appendWriteResource(self: *RGPass, res: *RGResource) void {
        self.writes_to.append(res) catch unreachable;
        res.writers.append(self) catch unreachable;
    }

    pub fn removeWriteResource(self: *RGPass, res: *RGResource) void {
        for (self.writes_to.items) |w, ind| {
            if (w == res) {
                _ = self.writes_to.swapRemove(ind);
                break;
            }
        }

        for (res.writers.items) |w, ind| {
            if (w == self) {
                _ = res.writers.swapRemove(ind);
                break;
            }
        }
    }
};
