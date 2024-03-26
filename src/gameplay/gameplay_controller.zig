const std = @import("std");

const Application = @import("../application/application.zig").Application;
const AssetMap = @import("../application/asset.zig").AssetMap;
const GameplaySystem = @import("gameplay_system.zig").GameplaySystem;
const System = @import("../system/system.zig").System;

pub const GameplayController = struct {
    name: []const u8,
    system: System,

    allocator: std.mem.Allocator,

    gameplay_systems: std.ArrayList(GameplaySystem),

    pub fn init(self: *GameplayController, comptime name: []const u8, allocator: std.mem.Allocator) void {
        self.allocator = allocator;
        self.name = name;

        self.system = System.create(name ++ " System", systemInit, systemDeinit, systemUpdate);

        self.gameplay_systems = std.ArrayList(GameplaySystem).init(self.allocator);
    }

    pub fn deinit(self: *GameplayController) void {
        self.gameplay_systems.deinit();
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

    pub fn createEmptyGameplaySystem(self: *GameplayController, name: []const u8) *GameplaySystem {
        const gs: *GameplaySystem = self.gameplay_systems.addOne() catch unreachable;
        gs.init(name, self.allocator);

        return gs;
    }
};
