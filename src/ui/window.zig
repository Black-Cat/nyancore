const Widget = @import("widget.zig").Widget;

pub const Window = struct {
    widget: Widget,
    open: bool,
    strId: [:0]const u8,
};
