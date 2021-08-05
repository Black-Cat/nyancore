const c = @import("../c.zig");
const std = @import("std");

pub const DockSpace = struct {
    id: []const u8,
    init_layout_fnc: fn (mainId: c.ImGuiID) void,

    pub fn init(self: *DockSpace, id: []const u8, init_layout_fnc: fn (mainId: c.ImGuiID) void) void {
        self.id = id;
        self.init_layout_fnc = init_layout_fnc;
    }

    pub fn deinit(self: *DockSpace) void {}

    pub fn drawBegin(self: *DockSpace) void {
        const viewport: *c.ImGuiViewport = c.igGetMainViewport();
        c.igSetNextWindowPos(viewport.Pos, 0, .{ .x = 0.0, .y = 0.0 });
        c.igSetNextWindowSize(viewport.Size, 0);
        c.igSetNextWindowViewport(viewport.ID);
        c.igSetNextWindowBgAlpha(0.0);

        const window_flags: c.ImGuiWindowFlags = c.ImGuiWindowFlags_NoBackground |
            c.ImGuiWindowFlags_NoDocking |
            c.ImGuiWindowFlags_MenuBar |
            c.ImGuiWindowFlags_NoTitleBar |
            c.ImGuiWindowFlags_NoCollapse |
            c.ImGuiWindowFlags_NoResize |
            c.ImGuiWindowFlags_NoMove |
            c.ImGuiWindowFlags_NoBringToFrontOnFocus |
            c.ImGuiWindowFlags_NoNavFocus;

        c.igPushStyleVar_Float(c.ImGuiStyleVar_WindowRounding, 0.0);
        c.igPushStyleVar_Float(c.ImGuiStyleVar_WindowBorderSize, 0.0);
        c.igPushStyleVar_Vec2(c.ImGuiStyleVar_WindowPadding, .{ .x = 0.0, .y = 0.0 });
        _ = c.igBegin("Dockspace", null, window_flags);
        c.igPopStyleVar(3);

        const dockspace_id: c.ImGuiID = c.igGetID_Str(self.id.ptr);
        const first_start: bool = c.igDockBuilderGetNode(dockspace_id) == null;

        c.igDockSpace(dockspace_id, .{ .x = 0.0, .y = 0.0 }, c.ImGuiDockNodeFlags_NoDockingInCentralNode, null);
        if (first_start)
            self.init_layout_fnc(dockspace_id);

        c.igDockBuilderSetCentralNoTabBar(dockspace_id);
    }

    pub fn drawEnd(self: *DockSpace) void {
        c.igEnd();
    }
};
