const std = @import("std");
const rg = @import("../../renderer/render_graph/render_graph.zig");
const application = @import("../../application/application.zig");

const Config = @import("../../application/config.zig").Config;
const DefaultRenderer = @import("../../renderer/default_renderer.zig").DefaultRenderer;
const System = @import("../../system/system.zig").System;

const ToolUI = @import("../tool_ui.zig").ToolUI;
const MeshViewerWindow = @import("mesh_viewer_window.zig").MeshViewerWindow;

fn setDefaultSettings() void {
    var config: *Config = application.app.config;
    config.putBool("swapchain_vsync", true);
}

pub fn main() !void {
    const allocator: std.mem.Allocator = std.testing.allocator;

    var renderer: DefaultRenderer = undefined;
    renderer.init("Main Renderer", allocator);

    var tool_ui: ToolUI = undefined;
    tool_ui.init(allocator);
    defer tool_ui.deinit();

    var window: MeshViewerWindow = undefined;
    window.init("Mesh Viewer", allocator, &tool_ui.ui.rg_pass);
    tool_ui.windows.append(&window.window) catch unreachable;

    try rg.global_render_graph.passes.append(&tool_ui.ui.rg_pass);

    const systems: []*System = &[_]*System{
        &renderer.system,
        &tool_ui.ui.system,
    };

    application.initGlobalData(allocator);
    defer application.deinitGlobalData();

    const app: *application.Application = &application.app;
    app.init("Nyancore Mesh Viewer", allocator, systems);
    defer app.deinit();

    setDefaultSettings();

    try app.initSystems();
    defer app.deinitSystems();

    try app.mainLoop();
}
