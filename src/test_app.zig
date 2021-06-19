pub usingnamespace @import("main.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

fn test_init(allocator: *Allocator) void {}
fn test_deinit() void {}
fn test_update(elapsed_time: f64) void {}

pub fn main() !void {
    var renderer: DefaultRenderer = undefined;
    renderer.init("Test Renderer", std.testing.allocator);

    var ui: UI = undefined;
    ui.init("Test UI");

    const systems: []*System = &[_]*System{
        &renderer.system,
        &ui.system,
    };

    initGlobalData(std.testing.allocator);
    defer deinitGlobalData();

    app.init("test_app", std.testing.allocator, systems);
    defer app.deinit();

    try app.start();
}
