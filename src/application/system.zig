const std = @import("std");

const Allocator = std.mem.Allocator;

pub const System = struct {
    name: []const u8,

    init: fn (allocator: *Allocator) void,
    deinit: fn () void,
    update: fn (elapsed_time: f64) void,

    pub fn create(comptime name: []const u8, comptime init: fn (allocator: *Allocator) void, comptime deinit: fn () void, comptime update: fn (elapsed_time: f64) void) System {
        return .{
            .name = name,
            .init = init,
            .deinit = deinit,
            .update = update,
        };
    }
};
