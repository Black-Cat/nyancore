const Widget = @import("widget.zig").Widget;

pub const Window = struct {
    widget: Widget,
    open: bool,
};
