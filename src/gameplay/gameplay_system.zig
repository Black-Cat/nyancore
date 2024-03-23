const std = @import("std");
const AssetMap = @import("../application/asset.zig").AssetMap;

// Gameplay systems are more specialized than regular systems
pub const GameplaySystem = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    nameZ: [:0]const u8,

    systemInit: ?*fn (system: *GameplaySystem) void = null,
    systemDeinit: ?*fn (system: *GameplaySystem) void = null,
    systemUpdate: ?*fn (system: *GameplaySystem, delta: f64) void = null,

    pub fn init(self: *GameplaySystem, name: []const u8, allocator: std.mem.Allocator) void {
        self.allocator = allocator;
        self.nameZ = self.allocator.dupeZ(u8, name) catch unreachable;
        self.name = self.nameZ[0 .. self.nameZ.len - 1];
    }

    pub fn deinit(self: *GameplaySystem) void {
        self.allocator.free(self.nameZ);
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
        gameplay_system.init(map.get("name") orelse unreachable, allocator) catch unreachable;
        return gameplay_system;
    }
};
