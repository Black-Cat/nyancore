const std = @import("std");

const Allocator = std.mem.Allocator;
const Application = @import("../application/application.zig").Application;

pub const System = struct {
    name: []const u8,

    init: fn (system: *System, app: *Application) void,
    deinit: fn (system: *System) void,
    update: fn (system: *System, elapsed_time: f64) void,

    pub fn create(comptime name: []const u8, comptime init: fn (system: *System, app: *Application) void, comptime deinit: fn (system: *System) void, comptime update: fn (system: *System, elapsed_time: f64) void) System {
        return .{
            .name = name,
            .init = init,
            .deinit = deinit,
            .update = update,
        };
    }
};
