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

        vulkan_context.init(self.allocator, app) catch @panic("Error during vulkan context initialization");

        self.createCommandPools() catch @panic("Error during command pools creation");

        var width: i32 = undefined;
        var height: i32 = undefined;
        c.glfwGetFramebufferSize(app.window, &width, &height);
        self.swapchain = undefined;
        self.swapchain.init(@intCast(u32, width), @intCast(u32, height), self.command_pool) catch @panic("Error during swapchain creation");

        self.createSyncObjects() catch @panic("Can't create sync objects");
    }

    fn systemDeinit(system: *System) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.destroySyncObjects();
        self.swapchain.deinit();

        self.destroyCommandPools();

        vulkan_context.deinit();
    }

    fn systemUpdate(system: *System, elapsed_time: f64) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.render(elapsed_time) catch @panic("Error during rendering");
    }

    fn createCommandPools(self: *DefaultRenderer) !void {
        var pool_info: vk.CommandPoolCreateInfo = .{
            .queue_family_index = vulkan_context.family_indices.graphics_family,
            .flags = .{
                .reset_command_buffer_bit = true,
            },
        };

        self.command_pool = vkd.createCommandPool(vulkan_context.device, pool_info, null) catch |err| {
            printVulkanError("Can't create command pool for graphics", err, self.allocator);
            return err;
        };

        pool_info.queue_family_index = vulkan_context.family_indices.compute_family;

        self.command_pool_compute = vkd.createCommandPool(vulkan_context.device, pool_info, null) catch |err| {
            printVulkanError("Can't create command pool for compute", err, self.allocator);
            return err;
        };
    }

    fn destroyCommandPools(self: *DefaultRenderer) void {
        vkd.destroyCommandPool(vulkan_context.device, self.command_pool, null);
        vkd.destroyCommandPool(vulkan_context.device, self.command_pool_compute, null);
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
            self.image_available_semaphores[i] = vkd.createSemaphore(vulkan_context.device, semaphore_info, null) catch |err| {
                printVulkanError("Can't create semaphore", err, self.allocator);
                return err;
            };
            self.render_finished_semaphores[i] = vkd.createSemaphore(vulkan_context.device, semaphore_info, null) catch |err| {
                printVulkanError("Can't create semaphore", err, self.allocator);
                return err;
            };
            self.in_flight_fences[i] = vkd.createFence(vulkan_context.device, fence_info, null) catch |err| {
                printVulkanError("Can't create fence", err, self.allocator);
                return err;
            };
        }
    }

    fn destroySyncObjects(self: *DefaultRenderer) void {
        var i: usize = 0;
        while (i < frames_in_flight) : (i += 1) {
            vkd.destroySemaphore(vulkan_context.device, self.image_available_semaphores[i], null);
            vkd.destroySemaphore(vulkan_context.device, self.render_finished_semaphores[i], null);
            vkd.destroyFence(vulkan_context.device, self.in_flight_fences[i], null);
        }
    }

    fn recreateSwapchain(self: *DefaultRenderer) !void {
        var width: c_int = undefined;
        var height: c_int = undefined;
        while (width == 0 or height == 0) {
            c.glfwGetFramebufferSize(self.app.window, &width, &height);
            c.glfwWaitEvents();
        }

        vkd.deviceWaitIdle(vulkan_context.device) catch |err| {
            printVulkanError("Can't wait for device idle while recreating swapchain", err, self.allocator);
            return err;
        };
        try self.swapchain.recreate(@intCast(u32, width), @intCast(u32, height));
    }

    fn render(self: *DefaultRenderer, elapsed_time: f64) !void {
        _ = vkd.waitForFences(vulkan_context.device, 1, @ptrCast([*]const vk.Fence, &self.in_flight_fences[self.current_frame]), vk.TRUE, std.math.maxInt(u64)) catch |err| {
            printVulkanError("Can't wait for a in flight fence", err, self.allocator);
            return err;
        };

        var image_index: u32 = undefined;
        const vkres_acquire: vk.Result = vkd.vkAcquireNextImageKHR(
            vulkan_context.device,
            self.swapchain.swapchain,
            std.math.maxInt(u64),
            self.image_available_semaphores[self.current_frame],
            .null_handle,
            &image_index,
        );

        if (vkres_acquire == .error_out_of_date_khr) {
            try self.recreateSwapchain();
            return;
        } else if (vkres_acquire != .success and vkres_acquire != .suboptimal_khr) {
            printError("Renderer", "Error while getting swapchain image");
            return error.Unknown;
        }

        const wait_stage: vk.PipelineStageFlags = .{
            .color_attachment_output_bit = true,
        };

        const submit_info: vk.SubmitInfo = .{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]vk.Semaphore, &self.image_available_semaphores[self.current_frame]),
            .p_wait_dst_stage_mask = @ptrCast([*]const vk.PipelineStageFlags, &wait_stage),

            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast([*]vk.CommandBuffer, &self.swapchain.command_buffers[image_index]),

            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast([*]vk.Semaphore, &self.render_finished_semaphores[image_index]),
        };

        vkd.resetFences(vulkan_context.device, 1, @ptrCast([*]vk.Fence, &self.in_flight_fences[self.current_frame])) catch |err| {
            printVulkanError("Can't reset in flight fence", err, self.allocator);
            return err;
        };

        vkd.queueSubmit(vulkan_context.graphics_queue, 1, @ptrCast([*]const vk.SubmitInfo, &submit_info), self.in_flight_fences[self.current_frame]) catch |err| {
            printVulkanError("Can't submit to graphics queue", err, self.allocator);
            return err;
        };

        const present_info: vk.PresentInfoKHR = .{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]vk.Semaphore, &self.render_finished_semaphores[self.current_frame]),

            .swapchain_count = 1,
            .p_swapchains = @ptrCast([*]vk.SwapchainKHR, &self.swapchain.swapchain),
            .p_image_indices = @ptrCast([*]const u32, &image_index),

            .p_results = null,
        };

        const vkres_present = vkd.vkQueuePresentKHR(vulkan_context.present_queue, &present_info);
        if (vkres_present == .error_out_of_date_khr or vkres_present == .suboptimal_khr) {
            try self.recreateSwapchain();
        } else if (vkres_present != .success) {
            printError("Vulkan Wrapper", "Can't queue present");
            return error.Unknown;
        }

        self.current_frame = (self.current_frame + 1) % frames_in_flight;
    }
};
