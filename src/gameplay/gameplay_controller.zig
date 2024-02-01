const std = @import("std");

const Application = @import("../application/application.zig").Application;
const System = @import("../system/system.zig").System;

pub const GameplayController = struct {
    name: []const u8,
    system: System,

    pub fn init(self: *GameplayController, comptime name: []const u8, allocator: std.mem.Allocator) void {
        _ = allocator;
        self.name = name;

        self.system = System.create(name ++ " System", systemInit, systemDeinit, systemUpdate);
    }

    fn systemInit(system: *System, app: *Application) void {
        _ = app;
        const self: *GameplayController = @fieldParentPtr(GameplayController, "system", system);
        _ = self;
    }

    fn systemDeinit(system: *System) void {
        const self: *GameplayController = @fieldParentPtr(GameplayController, "system", system);
        _ = self;
    }

    fn systemUpdate(system: *System, elapsed_time: f64) void {
        _ = elapsed_time;
        const self: *GameplayController = @fieldParentPtr(GameplayController, "system", system);
        _ = self;
    }
};
