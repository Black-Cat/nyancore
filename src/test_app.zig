pub usingnamespace @import("main.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

fn test_init(allocator: *Allocator) void {}
fn test_deinit() void {}
fn test_update(elapsed_time: f64) void {}

pub fn main() !void {
    const systems: []System = &[_]System{
        System.create("Test System", test_init, test_deinit, test_update),
        System.create("Test System", test_init, test_deinit, test_update),
    };

    var application: Application = undefined;
    application.init("test_app", std.testing.allocator, systems);
    defer application.deinit();

    try application.start();
}
