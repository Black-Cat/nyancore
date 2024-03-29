const std = @import("std");

const build_options = @import("nyancore_options");

const Application = @import("../application/application.zig").Application;
const AssetMap = @import("../application/asset.zig").AssetMap;
const GameplaySystem = @import("gameplay_system.zig").GameplaySystem;
const System = @import("../system/system.zig").System;

pub const GameplayController = struct {
    pub const DEFAULT_SYSTEMS_FOLDER: []const u8 = "./gameplay_systems/";

    name: []const u8,
    system: System,

    allocator: std.mem.Allocator,

    gameplay_systems: std.ArrayList(GameplaySystem),

    pub fn init(self: *GameplayController, comptime name: []const u8, allocator: std.mem.Allocator) void {
        self.allocator = allocator;
        self.name = name;

        self.system = System.create(name ++ " System", systemInit, systemDeinit, systemUpdate);

        self.gameplay_systems = std.ArrayList(GameplaySystem).init(self.allocator);

        self.loadSystemsFromFolder(DEFAULT_SYSTEMS_FOLDER);
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

    pub fn loadSystemsFromFolder(self: *GameplayController, path: []const u8) void {
        if (!build_options.dev_build)
            @compileError("Can't load gameplay systems from zig files in non dev build");

        const cwd: std.fs.Dir = std.fs.cwd();
        var folder: std.fs.IterableDir = cwd.openIterableDir(path, .{}) catch unreachable;
        defer folder.close();

        var walker: std.fs.IterableDir.Walker = folder.walk(self.allocator) catch unreachable;
        defer walker.deinit();

        while (walker.next() catch unreachable) |entry| {
            if (entry.kind != .file)
                continue;

            if (!std.mem.endsWith(u8, entry.basename, ".zig"))
                continue;

            const gs: *GameplaySystem = self.gameplay_systems.addOne() catch unreachable;
            gs.init(entry.basename[0 .. entry.basename.len - ".zig".len], self.allocator);
            gs.path = gs.allocator.dupe(u8, entry.path) catch unreachable;
        }
    }
};
