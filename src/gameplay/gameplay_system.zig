const std = @import("std");
const AssetMap = @import("../application/asset.zig").AssetMap;

// Gameplay systems are more specialized than regular systems
pub const GameplaySystem = struct {
    allocator: std.mem.Allocator,
    name: []const u8,

    systemInit: ?*fn (system: *GameplaySystem) void = null,
    systemDeinit: ?*fn (system: *GameplaySystem) void = null,
    systemUpdate: ?*fn (system: *GameplaySystem, delta: f64) void = null,

    pub fn init(self: *GameplaySystem, name: []const u8, allocator: std.mem.Allocator) void {
        self.allocator = allocator;
        self.name = self.allocator.dupe(u8, name) catch unreachable;
    }

    pub fn deinit(self: *GameplaySystem) void {
        self.allocator.free(self.name);
    }

    pub fn generateAssetMap(self: *GameplaySystem, allocator: std.mem.Allocator) AssetMap {
        var map: AssetMap = AssetMap.init(allocator);
        map.put("name", allocator.dupe(u8, self.name) catch unreachable) catch unreachable;
        return map;
    }

    pub fn deinitAssetMap(map: *AssetMap) void {
        map.allocator.free(map.get("name") orelse unreachable);
        map.deinit();
    }

    pub fn createFromAssetMap(map: *AssetMap, allocator: std.mem.Allocator) GameplaySystem {
        var gameplay_system: GameplaySystem = undefined;
        gameplay_system.name = allocator.dupe(u8, map.get("name") orelse unreachable) catch unreachable;
        return gameplay_system;
    }
};
