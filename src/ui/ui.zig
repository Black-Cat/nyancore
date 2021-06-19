const c = @import("../c.zig");

const Application = @import("../application/application.zig").Application;
const System = @import("../system/system.zig").System;

pub const UI = struct {
    app: *Application,
    name: []const u8,
    system: System,

    context: *c.ImGuiContext,

    pub fn init(self: *UI, comptime name: []const u8) void {
        self.name = name;

        self.system = System.create(name ++ " System", systemInit, systemDeinit, systemUpdate);
    }

    fn systemInit(system: *System, app: *Application) void {
        const self: *UI = @fieldParentPtr(UI, "system", system);

        self.app = app;

        self.context = c.igCreateContext(null);
    }

    fn systemDeinit(system: *System) void {
        const self: *UI = @fieldParentPtr(UI, "system", system);

        c.igDestroyContext(self.context);
    }

    fn systemUpdate(system: *System, elapsed_time: f64) void {
        const self: *UI = @fieldParentPtr(UI, "system", system);
    }
};
