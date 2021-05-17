pub usingnamespace @import("main.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
const DefaultRenderer = @import("renderer/default_renderer.zig").DefaultRenderer;

fn test_init(allocator: *Allocator) void {}
fn test_deinit() void {}
fn test_update(elapsed_time: f64) void {}

pub fn main() !void {
    var renderer: DefaultRenderer = undefined;
    renderer.init("Test Renderer", std.testing.allocator);

    const systems: []*System = &[_]*System{
        &renderer.system,
    };

    initGlobalData(std.testing.allocator);
    defer deinitGlobalData();

    var application: Application = undefined;
    application.init("test_app", std.testing.allocator, systems);
    defer application.deinit();

    try application.start();
}
