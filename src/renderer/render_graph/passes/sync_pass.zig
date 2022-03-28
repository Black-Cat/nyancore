const vk = @import("../../../vk.zig");
const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");

const Allocator = @import("std").mem.Allocator;
const RGPass = @import("../render_graph_pass.zig").RGPass;
const RGResource = @import("../render_graph_resource.zig").RGResource;
const SyncPoint = @import("../resources/sync_point.zig").SyncPoint;

pub const SyncPass = struct {
    rg_pass: RGPass,

    input_sync_point: SyncPoint,
    output_sync_point: SyncPoint,

    pub fn init(self: *SyncPass, comptime name: []const u8, allocator: Allocator) void {
        self.rg_pass.init(name, allocator, passInit, passDeinit, passRender);

        self.input_sync_point.rg_resource.init(name ++ "'s Input Sync Point", allocator);
        self.output_sync_point.rg_resource.init(name ++ "'s Output Sync Point", allocator);

        self.rg_pass.appendReadResource(&self.input_sync_point.rg_resource);
        self.rg_pass.appendWriteResource(&self.output_sync_point.rg_resource);
    }

    pub fn deinit(self: *SyncPass) void {
        _ = self;
    }

    fn passInit(render_pass: *RGPass) void {
        _ = render_pass;
    }

    fn passDeinit(render_pass: *RGPass) void {
        _ = render_pass;
    }

    fn passRender(render_pass: *RGPass, command_buffer: vk.CommandBuffer, frame_index: u32) void {
        _ = frame_index;

        vkctxt.vkd.cmdPipelineBarrier(
            command_buffer,
            render_pass.pipeline_start,
            render_pass.pipeline_end,
            .{},
            0,
            undefined,
            0,
            undefined,
            0,
            undefined,
        );
    }
};
