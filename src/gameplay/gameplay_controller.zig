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
    gameplay_systems_paths: std.ArrayList([]const u8),

    pub fn init(self: *GameplayController, comptime name: []const u8, allocator: std.mem.Allocator) void {
        self.allocator = allocator;
        self.name = name;

        self.system = System.create(name ++ " System", systemInit, systemDeinit, systemUpdate);

        self.gameplay_systems = std.ArrayList(GameplaySystem).init(self.allocator);
        self.gameplay_systems_paths = std.ArrayList([]const u8).init(self.allocator);
    }

    pub fn deinit(self: *GameplayController) void {
        self.gameplay_systems.deinit();

        for (self.gameplay_systems_paths) |p|
            self.allocator.free(p);
        self.gameplay_systems_paths.deinit();
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

    pub fn generateAssetMap(self: *GameplayController, allocator: std.mem.Allocator) AssetMap {
        var pathes: []u8 = std.mem.join(allocator, "\n", self.gameplay_systems_paths.items) catch unreachable;

        var map: AssetMap = AssetMap.init(allocator);
        map.put("pathes", pathes) catch unreachable;
        return map;
    }

    pub fn deinitAssetMap(map: *AssetMap) void {
        map.allocator.free(map.get("pathes") orelse unreachable);
        map.deinit();
    }

    pub fn createFromAssetMap(map: *AssetMap, comptime name: []const u8, allocator: std.mem.Allocator) GameplayController {
        var gameplay_controller: GameplayController = undefined;
        gameplay_controller.init(name, allocator);

        var pathes: []u8 = map.get("pathes") orelse unreachable;
        var it = std.mem.tokenizeSequence(u8, pathes, "\n");
        while (it.next()) |path|
            gameplay_controller.gameplay_systems_paths.append(allocator.dupe(path) catch unreachable) catch unreachable;

        return gameplay_controller;
    }

    pub fn createEmptyGameplaySystem(self: *GameplayController, name: []const u8) *GameplaySystem {
        const gs: *GameplaySystem = self.gameplay_systems.addOne() catch unreachable;
        gs.init(name, self.allocator);

        self.gameplay_systems_paths.append("") catch unreachable;

        return gs;
    }
};
