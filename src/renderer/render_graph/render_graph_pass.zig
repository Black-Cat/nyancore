const std = @import("std");

const RGResource = @import("render_graph_resource.zig").RGResource;
const RenderGraph = @import("render_graph.zig").RenderGraph;

const ResourceList = std.ArrayList(*RGResource);
const PassList = std.ArrayList(*RGPass);

pub const RGPass = struct {
    const PassFunction = fn (render_pass: *RGPass) void;

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

    fn appendResource(self: *RGPass, list: *ResourceList, res_list: *PassList, res: *RGResource) void {
        list.append(res) catch unreachable;
        res_list.append(self) catch unreachable;
    }

    pub fn appendWriteResource(self: *RGPass, res: *RGResource) void {
        self.appendResource(&self.writes_to, &res.writers, res);
    }

    pub fn appendReadResource(self: *RGPass, res: *RGResource) void {
        self.appendResource(&self.reads_from, &res.readers, res);
    }

    fn removeResource(self: *RGPass, list: *ResourceList, res_list: *PassList, res: *RGResource) void {
        for (list.items) |r, ind| {
            if (r == res) {
                _ = list.swapRemove(ind);
                break;
            }
        }

        for (res_list.items) |p, ind| {
            if (p == self) {
                _ = res_list.swapRemove(ind);
                break;
            }
        }
    }

    pub fn removeWriteResource(self: *RGPass, res: *RGResource) void {
        self.removeResource(&self.writes_to, &res.writers, res);
    }

    pub fn removeReadResource(self: *RGPass, res: *RGResource) void {
        self.removeResource(&self.reads_from, &res.readers, res);
    }
};
