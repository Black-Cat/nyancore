const std = @import("std");
const RGPass = @import("../render_graph_pass.zig").RGPass;

pub const ScreenRenderPass = struct {
    rg_pass: RGPass,

    pub fn init(self: *ScreenRenderPass, name: []const u8, allocator: *std.mem.Allocator) void {
        self.rg_pass.init(name, allocator, passInit, passDeinit);
    }

    fn passInit(render_pass: *RGPass) void {}

    fn passDeinit(render_pass: *RGPass) void {}
};
