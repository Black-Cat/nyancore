const c = @import("../c.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;
const Widget = @import("widget.zig").Widget;
const Window = @import("window.zig").Window;

pub const DummyWindow = struct {
    window: Window,
    allocator: Allocator,

    pub fn init(self: *DummyWindow, name: []const u8, allocator: Allocator) void {
        self.allocator = allocator;
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = true,
            .strId = allocator.dupeZ(u8, name) catch unreachable,
        };
    }

    pub fn deinit(self: *DummyWindow) void {
        self.allocator.free(self.window.strId);
    }

    fn windowInit(widget: *Widget) void {
        _ = widget;
    }
    fn windowDeinit(widget: *Widget) void {
        _ = widget;
    }
    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *DummyWindow = @fieldParentPtr(DummyWindow, "window", window);

        if (window.open) {
            _ = c.igBegin(self.window.strId.ptr, &window.open, c.ImGuiWindowFlags_None);
            c.igText("Test");
            c.igEnd();
        }
    }
};
