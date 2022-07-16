const std = @import("std");
const c = @import("../c.zig");

const Allocator = std.mem.Allocator;
const UI = @import("../ui/ui.zig").UI;
const Window = @import("../ui/window.zig").Window;
const System = @import("../system/system.zig").System;
const Application = @import("../application/application.zig").Application;

fn hexToColor(col: u24) c.ImVec4 {
    const ch = std.mem.asBytes(&col);
    return .{
        .x = @intToFloat(f16, ch[0]) / 255.0,
        .y = @intToFloat(f16, ch[1]) / 255.0,
        .z = @intToFloat(f16, ch[2]) / 255.0,
        .w = 1.0,
    };
}

pub const mainColors = [_]c.ImVec4{
    hexToColor(0x041634), // Oxford Blue
    hexToColor(0x01081E), // Xiketic
    hexToColor(0xC79C65), // Camel
    hexToColor(0xDF7716), // Ochre
    hexToColor(0x122F60), // Space Cadet
};

fn mainColorWithTransparency(ind: usize, transparency: f32) c.ImVec4 {
    var col = mainColors[ind];
    col.w = transparency;
    return col;
}

pub const ToolUI = struct {
    ui: UI,

    windows: std.ArrayList(*Window),

    ui_system_init_fn: fn (system: *System, app: *Application) void,
    ui_system_deinit_fn: fn (system: *System) void,

    pub fn init(self: *ToolUI, allocator: Allocator) void {
        self.windows = std.ArrayList(*Window).init(allocator);

        self.ui.init("Tool UI", allocator);
        self.ui.paletteFn = ToolUI.palette;
        self.ui.drawFn = ToolUI.draw;

        self.ui_system_init_fn = self.ui.system.init;
        self.ui.system.init = systemInit;

        self.ui_system_deinit_fn = self.ui.system.deinit;
        self.ui.system.deinit = systemDeinit;

        self.ui.rg_pass.initial_layout = .color_attachment_optimal;
        self.ui.rg_pass.load_op = .load;
    }

    pub fn deinit(self: *ToolUI) void {
        self.windows.deinit();
    }

    pub fn activateWindow(self: *ToolUI, window: *Window) void {
        window.widget.init(&window.widget);
        self.windows.append(window) catch unreachable;
    }

    pub fn deactivateWindow(self: *ToolUI, window: *Window) void {
        window.widget.deinit(&window.widget);
        for (self.windows.items) |w, i| {
            if (w == window) {
                _ = self.windows.swapRemove(i);
                break;
            }
        }
    }

    fn systemInit(system: *System, app: *Application) void {
        const ui: *UI = @fieldParentPtr(UI, "system", system);
        const self: *ToolUI = @fieldParentPtr(ToolUI, "ui", ui);

        self.ui_system_init_fn(system, app);

        for (self.windows.items) |w|
            w.widget.init(&w.widget);
    }

    fn systemDeinit(system: *System) void {
        const ui: *UI = @fieldParentPtr(UI, "system", system);
        const self: *ToolUI = @fieldParentPtr(ToolUI, "ui", ui);

        for (self.windows.items) |w|
            w.widget.deinit(&w.widget);

        self.ui_system_deinit_fn(system);
    }

    fn draw(ui: *UI) void {
        const self: *ToolUI = @fieldParentPtr(ToolUI, "ui", ui);

        for (self.windows.items) |w|
            w.widget.draw(&w.widget);
    }

    fn palette(col: c.ImGuiCol_) c.ImVec4 {
        return switch (col) {
            c.ImGuiCol_Text => .{ .x = 0.0, .y = 0.1, .z = 0.1, .w = 1.0 },
            c.ImGuiCol_TextDisabled => mainColors[1],
            c.ImGuiCol_WindowBg => mainColors[3],
            c.ImGuiCol_ChildBg => mainColors[3],
            c.ImGuiCol_PopupBg => mainColors[2],
            c.ImGuiCol_Border => mainColors[1],
            c.ImGuiCol_BorderShadow => mainColors[1],
            c.ImGuiCol_FrameBg => mainColors[4],
            c.ImGuiCol_FrameBgHovered => mainColors[1],
            c.ImGuiCol_FrameBgActive => mainColors[2],
            c.ImGuiCol_TitleBg => mainColors[0],
            c.ImGuiCol_TitleBgActive => mainColors[1],
            c.ImGuiCol_TitleBgCollapsed => mainColors[2],
            c.ImGuiCol_MenuBarBg => mainColors[4],
            c.ImGuiCol_ScrollbarBg => mainColors[2],
            c.ImGuiCol_ScrollbarGrab => mainColors[1],
            c.ImGuiCol_ScrollbarGrabHovered => mainColors[1],
            c.ImGuiCol_ScrollbarGrabActive => mainColors[4],
            c.ImGuiCol_CheckMark => mainColors[0],
            c.ImGuiCol_SliderGrab => mainColors[3],
            c.ImGuiCol_SliderGrabActive => mainColors[4],
            c.ImGuiCol_Button => mainColors[0],
            c.ImGuiCol_ButtonHovered => mainColors[1],
            c.ImGuiCol_ButtonActive => mainColors[2],
            c.ImGuiCol_Header => mainColors[0],
            c.ImGuiCol_HeaderHovered => mainColors[1],
            c.ImGuiCol_HeaderActive => mainColors[2],
            c.ImGuiCol_Separator => mainColors[0],
            c.ImGuiCol_SeparatorHovered => mainColors[1],
            c.ImGuiCol_SeparatorActive => mainColors[2],
            c.ImGuiCol_ResizeGrip => mainColors[0],
            c.ImGuiCol_ResizeGripHovered => mainColors[1],
            c.ImGuiCol_ResizeGripActive => mainColors[2],
            c.ImGuiCol_Tab => mainColors[0],
            c.ImGuiCol_TabHovered => mainColors[1],
            c.ImGuiCol_TabActive => mainColors[2],
            c.ImGuiCol_TabUnfocused => mainColorWithTransparency(1, 0.8),
            c.ImGuiCol_TabUnfocusedActive => mainColorWithTransparency(2, 0.8),
            c.ImGuiCol_PlotLines => mainColors[0],
            c.ImGuiCol_PlotLinesHovered => mainColors[1],
            c.ImGuiCol_PlotHistogram => mainColors[1],
            c.ImGuiCol_PlotHistogramHovered => mainColors[0],
            c.ImGuiCol_TableHeaderBg => mainColors[4],
            c.ImGuiCol_TableBorderStrong => mainColors[1],
            c.ImGuiCol_TableBorderLight => mainColors[4],
            c.ImGuiCol_TableRowBg => mainColors[0],
            c.ImGuiCol_TableRowBgAlt => mainColors[4],
            c.ImGuiCol_TextSelectedBg => mainColors[1],
            c.ImGuiCol_DragDropTarget => mainColors[2],
            c.ImGuiCol_NavHighlight => mainColors[3],
            c.ImGuiCol_NavWindowingHighlight => mainColors[3],
            c.ImGuiCol_NavWindowingDimBg => mainColors[0],
            c.ImGuiCol_ModalWindowDimBg => mainColorWithTransparency(1, 0.5),
            else => @panic("Unknown Style"),
        };
    }
};
