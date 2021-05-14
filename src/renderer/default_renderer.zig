const std = @import("std");
const vk = @import("vulkan");

const Allocator = std.mem.Allocator;
const Application = @import("../application/application.zig").Application;
pub const System = @import("../system/system.zig").System;
const printError = @import("../application/print_error.zig").printError;
const VulkanContext = @import("vulkan_context.zig").VulkanContext;

const frames_in_flight: usize = 2;

pub const DefaultRenderer = struct {
    allocator: *Allocator,
    name: []const u8,
    system: System,

    context: VulkanContext,

    pub fn init(self: *DefaultRenderer, comptime name: []const u8, allocator: *Allocator) void {
        self.allocator = allocator;
        self.name = name;

        self.system = System.create(name ++ " System", system_init, system_deinit, system_update);
    }

    fn system_init(system: *System, app: *Application) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.context.init(self.allocator, app) catch |err| @panic("Error during vulkan context initialization");
    }

    fn system_deinit(system: *System) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);
    }

    fn system_update(system: *System, elapsed_time: f64) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);
    }
};
