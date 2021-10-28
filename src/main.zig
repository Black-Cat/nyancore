pub usingnamespace @import("application/application.zig");
pub usingnamespace @import("application/print_error.zig");
pub usingnamespace @import("renderer/render_graph/render_graph.zig");
pub usingnamespace @import("renderer/render_graph/passes/passes.zig");
pub usingnamespace @import("renderer/render_graph/resources/resources.zig");

pub const c = @import("c.zig");
pub const vk = @import("vk.zig");
pub const vkw = @import("vulkan_wrapper/vulkan_wrapper.zig");

pub const DefaultRenderer = @import("renderer/default_renderer.zig").DefaultRenderer;
pub const UI = @import("ui/ui.zig").UI;
pub const Math = @import("math/math.zig");

pub const RGResource = @import("renderer/render_graph/render_graph_resource.zig").RGResource;

pub const Widgets = struct {
    pub const DockSpace = @import("ui/dockspace.zig").DockSpace;
    pub const DummyWindow = @import("ui/dummy_window.zig").DummyWindow;
    pub const Widget = @import("ui/widget.zig").Widget;
    pub const Window = @import("ui/window.zig").Window;
};

pub const shader_util = @import("shaders/shader_util.zig");
