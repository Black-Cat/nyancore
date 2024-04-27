const std = @import("std");
const AssetMap = @import("../application/asset.zig").AssetMap;

// Gameplay systems are more specialized than regular systems
pub const GameplaySystem = struct {
    allocator: std.mem.Allocator,
    name: []u8,
    nameZ: [:0]u8,

    path: ?[]const u8,
    modified: bool,

    systemInit: ?*fn (system: *GameplaySystem) void = null,
    systemDeinit: ?*fn (system: *GameplaySystem) void = null,
    systemUpdate: ?*fn (system: *GameplaySystem, delta: f64) void = null,

    pub fn init(self: *GameplaySystem, name: []const u8, allocator: std.mem.Allocator) void {
        self.allocator = allocator;
        self.nameZ = self.allocator.dupeZ(u8, name) catch unreachable;
        self.name = self.nameZ[0..self.nameZ.len];

        self.path = null;
        self.modified = false;
    }

    pub fn deinit(self: *GameplaySystem) void {
        self.allocator.free(self.nameZ);

        if (self.path) |p|
            self.allocator.free(p);
    }

    pub fn save(self: *GameplaySystem, folder_path: []const u8) void {
        var cwd: std.fs.Dir = std.fs.cwd();
        cwd = cwd.makeOpenPath(folder_path, .{}) catch unreachable;

        var file_name: []const u8 = std.mem.concat(self.allocator, u8, &.{ self.name, ".zig" }) catch unreachable;
        defer self.allocator.free(file_name);

        const file: std.fs.File = cwd.createFile(file_name, .{ .read = true, .truncate = true }) catch unreachable;
        defer file.close();

        if (self.path) |p| {
            // Was renamed
            if (!std.mem.endsWith(u8, p, file_name)) {
                cwd.deleteFile(p) catch unreachable;
            }
            self.allocator.free(p);
        }
        self.path = self.allocator.dupe(u8, file_name) catch unreachable;

        self.modified = false;
    }

    pub fn rename(self: *GameplaySystem, new_name: []const u8) void {
        if (std.mem.eql(u8, self.name, new_name))
            return;

        self.modified = true;

        self.allocator.free(self.nameZ);

        self.nameZ = self.allocator.dupeZ(u8, new_name) catch unreachable;
        self.name = self.nameZ[0..self.nameZ.len];
    }
};
