const std = @import("std");
const vk = @import("../../vk.zig");

const RGResource = @import("render_graph_resource.zig").RGResource;
const RenderGraph = @import("render_graph.zig").RenderGraph;
const SyncPoint = @import("resources/sync_point.zig").SyncPoint;
const CommandBuffer = @import("../../vulkan_wrapper/command_buffer.zig").CommandBuffer;

const ResourceList = std.ArrayList(*RGResource);
const PassList = std.ArrayList(*RGPass);

pub const RGPass = struct {
    const PassFunction = fn (render_pass: *RGPass) void;
    const RenderFunction = fn (render_pass: *RGPass, command_buffer: *CommandBuffer, frame_index: u32) void;

    name: []const u8,

    writes_to: ResourceList,
    reads_from: ResourceList,

    initFn: PassFunction,
    deinitFn: PassFunction,
    renderFn: RenderFunction,

    load_op: vk.AttachmentLoadOp,
    initial_layout: vk.ImageLayout,
    final_layout: vk.ImageLayout,

    sync_point: SyncPoint,

    pipeline_start: vk.PipelineStageFlags = .{ .top_of_pipe_bit = true },
    pipeline_end: vk.PipelineStageFlags = .{ .bottom_of_pipe_bit = true },

    pub fn init(self: *RGPass, comptime name: []const u8, allocator: std.mem.Allocator, initFn: PassFunction, deinitFn: PassFunction, renderFn: RenderFunction) void {
        self.name = name;
        self.initFn = initFn;
        self.deinitFn = deinitFn;
        self.renderFn = renderFn;

        self.writes_to = ResourceList.init(allocator);
        self.reads_from = ResourceList.init(allocator);

        self.load_op = .clear;
        self.initial_layout = .@"undefined";
        self.final_layout = .present_src_khr;

        self.sync_point.rg_resource.init(name ++ "'s Sync Point", allocator);
        self.appendReadResource(&self.sync_point.rg_resource);
    }

    pub fn deinit(self: *RGPass) void {
        self.sync_point.rg_resource.deinit();

        self.writes_to.deinit();
        self.reads_from.deinit();
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
