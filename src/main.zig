pub usingnamespace @import("application/application.zig");

pub const c = @import("c.zig");

pub const DefaultRenderer = @import("renderer/default_renderer.zig").DefaultRenderer;
pub const UI = @import("ui/ui.zig").UI;

pub const Widgets = struct {
    pub const DockSpace = @import("ui/dockspace.zig").DockSpace;
};
