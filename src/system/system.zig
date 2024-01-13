const std = @import("std");

const Allocator = std.mem.Allocator;
const Application = @import("../application/application.zig").Application;

pub const System = struct {
    name: []const u8,

    init: *const fn (system: *System, app: *Application) void,
    deinit: *const fn (system: *System) void,
    update: *const fn (system: *System, elapsed_time: f64) void,

    pub fn create(
        comptime name: []const u8,
        init: *const fn (system: *System, app: *Application) void,
        deinit: *const fn (system: *System) void,
        update: *const fn (system: *System, elapsed_time: f64) void,
    ) System {
        return .{
            .name = name,
            .init = init,
            .deinit = deinit,
            .update = update,
        };
    }
};
