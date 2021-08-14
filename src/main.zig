pub usingnamespace @import("application/application.zig");

pub const c = @import("c.zig");

pub const global_config = &@import("application/config.zig").global_config;
pub const DefaultRenderer = @import("renderer/default_renderer.zig").DefaultRenderer;
pub const UI = @import("ui/ui.zig").UI;

pub const Widgets = struct {
    pub const DockSpace = @import("ui/dockspace.zig").DockSpace;
    pub const DummyWindow = @import("ui/dummy_window.zig").DummyWindow;
    pub const Widget = @import("ui/widget.zig").Widget;
    pub const Window = @import("ui/window.zig").Window;
};
