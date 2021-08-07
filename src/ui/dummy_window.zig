const c = @import("../c.zig");
const std = @import("std");

const Allocator = std.mem.Allocator;
const Widget = @import("widget.zig").Widget;
const Window = @import("window.zig").Window;

pub const DummyWindow = struct {
    window: Window,
    name: [:0]const u8,
    allocator: *Allocator,

    pub fn init(self: *DummyWindow, name: []const u8, allocator: *Allocator) void {
        self.allocator = allocator;
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = true,
        };

        self.name = allocator.dupeZ(u8, name) catch unreachable;
    }

    pub fn deinit(self: *DummyWindow) void {
        self.allocator.free(self.name);
    }

    pub fn draw(self: *DummyWindow) void {
        self.window.widget.draw(&self.window.widget);
    }

    fn windowInit(widget: *Widget) void {}
    fn windowDeinit(widget: *Widget) void {}
    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *DummyWindow = @fieldParentPtr(DummyWindow, "window", window);

        _ = c.igBegin(self.name.ptr, &window.open, c.ImGuiWindowFlags_None);
        c.igText("Test");
        c.igEnd();
    }
};
