const std = @import("std");
const vk = @import("vulkan");
const c = @import("../c.zig");

usingnamespace @import("../vulkan_wrapper/vulkan_wrapper.zig");

const Allocator = std.mem.Allocator;
const Application = @import("../application/application.zig").Application;
pub const System = @import("../system/system.zig").System;

const printError = @import("../application/print_error.zig").printError;

const frames_in_flight: usize = 2;

pub const DefaultRenderer = struct {
    allocator: *Allocator,
    name: []const u8,
    system: System,
    app: *Application,

    context: VulkanContext,

    command_pool: vk.CommandPool,
    command_pool_compute: vk.CommandPool,
    swapchain: Swapchain,

    image_available_semaphores: [frames_in_flight]vk.Semaphore,
    render_finished_semaphores: [frames_in_flight]vk.Semaphore,
    in_flight_fences: [frames_in_flight]vk.Fence,
    current_frame: usize,

    framebuffer_resized: bool,

    pub fn init(self: *DefaultRenderer, comptime name: []const u8, allocator: *Allocator) void {
        self.allocator = allocator;
        self.name = name;
        self.framebuffer_resized = false;
        self.current_frame = 0;

        self.system = System.create(name ++ " System", systemInit, systemDeinit, systemUpdate);
    }

    fn systemInit(system: *System, app: *Application) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.app = app;

        self.context.init(self.allocator, app) catch @panic("Error during vulkan context initialization");

        self.createCommandPools() catch @panic("Error during command pools creation");

        var width: i32 = undefined;
        var height: i32 = undefined;
        c.glfwGetFramebufferSize(app.window, &width, &height);
        self.swapchain = undefined;
        self.swapchain.init(&self.context, @intCast(u32, width), @intCast(u32, height), self.command_pool) catch @panic("Error during swapchain creation");

        self.createSyncObjects() catch @panic("Can't create sync objects");
    }

    fn systemDeinit(system: *System) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.destroySyncObjects();
        self.swapchain.deinit(&self.context);

        self.destroyCommandPools();

        self.context.deinit();
    }

    fn systemUpdate(system: *System, elapsed_time: f64) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.render(elapsed_time) catch @panic("Error during rendering");
    }

    fn createCommandPools(self: *DefaultRenderer) !void {
        var pool_info: vk.CommandPoolCreateInfo = .{
            .queue_family_index = self.context.family_indices.graphics_family,
            .flags = .{
                .reset_command_buffer_bit = true,
            },
        };

        self.command_pool = self.context.vkd.createCommandPool(self.context.device, pool_info, null) catch |err| {
            printVulkanError("Can't create command pool for graphics", err, self.allocator);
            return err;
        };

        pool_info.queue_family_index = self.context.family_indices.compute_family;

        self.command_pool_compute = self.context.vkd.createCommandPool(self.context.device, pool_info, null) catch |err| {
            printVulkanError("Can't create command pool for compute", err, self.allocator);
            return err;
        };
    }

    fn destroyCommandPools(self: *DefaultRenderer) void {
        self.context.vkd.destroyCommandPool(self.context.device, self.command_pool, null);
        self.context.vkd.destroyCommandPool(self.context.device, self.command_pool_compute, null);
    }

    fn createSyncObjects(self: *DefaultRenderer) !void {
        const semaphore_info: vk.SemaphoreCreateInfo = .{
            .flags = .{},
        };
        const fence_info: vk.FenceCreateInfo = .{
            .flags = .{
                .signaled_bit = true,
            },
        };

        var i: usize = 0;
        while (i < frames_in_flight) : (i += 1) {
            self.image_available_semaphores[i] = self.context.vkd.createSemaphore(self.context.device, semaphore_info, null) catch |err| {
                printVulkanError("Can't create semaphore", err, self.allocator);
                return err;
            };
            self.render_finished_semaphores[i] = self.context.vkd.createSemaphore(self.context.device, semaphore_info, null) catch |err| {
                printVulkanError("Can't create semaphore", err, self.allocator);
                return err;
            };
            self.in_flight_fences[i] = self.context.vkd.createFence(self.context.device, fence_info, null) catch |err| {
                printVulkanError("Can't create fence", err, self.allocator);
                return err;
            };
        }
    }

    fn destroySyncObjects(self: *DefaultRenderer) void {
        var i: usize = 0;
        while (i < frames_in_flight) : (i += 1) {
            self.context.vkd.destroySemaphore(self.context.device, self.image_available_semaphores[i], null);
            self.context.vkd.destroySemaphore(self.context.device, self.render_finished_semaphores[i], null);
            self.context.vkd.destroyFence(self.context.device, self.in_flight_fences[i], null);
        }
    }

    fn recreateSwapchain(self: *DefaultRenderer) !void {
        var width: c_int = undefined;
        var height: c_int = undefined;
        while (width == 0 or height == 0) {
            c.glfwGetFramebufferSize(self.app.window, &width, &height);
            c.glfwWaitEvents();
        }

        self.context.vkd.deviceWaitIdle(self.context.device) catch |err| {
            printVulkanError("Can't wait for device idle while recreating swapchain", err, self.allocator);
            return err;
        };
        try self.swapchain.recreate(&self.context, @intCast(u32, width), @intCast(u32, height));
    }

    fn render(self: *DefaultRenderer, elapsed_time: f64) !void {
        _ = self.context.vkd.waitForFences(self.context.device, 1, @ptrCast([*]const vk.Fence, &self.in_flight_fences[self.current_frame]), vk.TRUE, std.math.maxInt(u64)) catch |err| {
            printVulkanError("Can't wait for a in flight fence", err, self.allocator);
            return err;
        };

        var image_index: u32 = undefined;
        const res: vk.Result = self.context.vkd.vkAcquireNextImageKHR(
            self.context.device,
            self.swapchain.swapchain,
            std.math.maxInt(u64),
            self.image_available_semaphores[self.current_frame],
            .null_handle,
            &image_index,
        );

        if (res == .error_out_of_date_khr) {
            try self.recreateSwapchain();
            return;
        } else if (res != .success and res != .suboptimal_khr) {
            printError("Renderer", "Error while getting swapchain image");
            return error.Unknown;
        }
    }
};
