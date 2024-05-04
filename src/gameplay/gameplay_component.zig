const std = @import("std");

pub const GameplayComponent = struct {
    const ComponentType = enum {
        Point,
    };

    allocator: std.mem.Allocator,
    name: []const u8,
    nameZ: [:0]const u8,
    component_type: ComponentType,

    pub fn newComponent(allocator: std.mem.Allocator) GameplayComponent {
        var gc: GameplayComponent = undefined;

        gc.allocator = allocator;
        gc.component_type = .Point;
        gc.nameZ = gc.allocator.dupeZ(u8, "unnamed_component") catch unreachable;
        gc.name = gc.nameZ[0..gc.nameZ.len];
        return gc;
    }

    pub fn deinit(self: *GameplayComponent) void {
        self.allocator.free(self.nameZ);
    }

    pub fn rename(self: *GameplayComponent, new_name: []const u8) bool {
        if (std.mem.eql(u8, new_name, self.nameZ))
            return false;

        self.allocator.free(self.nameZ);
        self.nameZ = self.allocator.dupeZ(u8, new_name) catch unreachable;
        self.name = self.nameZ[0..self.nameZ.len];
        return true;
    }
};
