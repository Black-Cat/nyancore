const std = @import("std");
const vk = @import("../vk.zig");
const c = @import("../c.zig");

usingnamespace @import("../vulkan_wrapper/vulkan_wrapper.zig");

const Allocator = std.mem.Allocator;
const Application = @import("../application/application.zig").Application;
pub const System = @import("../system/system.zig").System;

const rg = @import("render_graph/render_graph.zig");
const RenderGraph = rg.RenderGraph;
const RGPass = @import("render_graph/render_graph_pass.zig").RGPass;
const RGResource = @import("render_graph/render_graph_resource.zig").RGResource;

const printError = @import("../application/print_error.zig").printError;

const frames_in_flight: u32 = 2;

pub const DefaultRenderer = struct {
    allocator: *Allocator,
    name: []const u8,
    system: System,
    app: *Application,

    image_available_semaphores: [frames_in_flight]vk.Semaphore,
    render_finished_semaphores: [frames_in_flight]vk.Semaphore,
    in_flight_fences: [frames_in_flight]vk.Fence,
    image_index: u32,

    framebuffer_resized: bool,

    renderCtx: std.ArrayList(*System),
    renderFns: std.ArrayList(fn (system: *System, index: u32) vk.CommandBuffer),

    pub fn init(self: *DefaultRenderer, comptime name: []const u8, allocator: *Allocator) void {
        self.allocator = allocator;
        self.name = name;
        self.framebuffer_resized = false;
        self.image_index = 0;
        self.renderCtx = std.ArrayList(*System).init(allocator);
        self.renderFns = std.ArrayList(fn (system: *System, index: u32) vk.CommandBuffer).init(allocator);

        self.system = System.create(name ++ " System", systemInit, systemDeinit, systemUpdate);

        rg.global_render_graph.passes = std.ArrayList(*RGPass).init(self.allocator);
        rg.global_render_graph.resources = std.ArrayList(*RGResource).init(self.allocator);
        rg.global_render_graph.frame_index = 0;
    }

    fn systemInit(system: *System, app: *Application) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.app = app;

        vkc.init(self.allocator, app) catch @panic("Error during vulkan context initialization");

        var width: i32 = undefined;
        var height: i32 = undefined;
        c.glfwGetFramebufferSize(app.window, &width, &height);

        rg.global_render_graph.final_swapchain.rg_resource.init("Final Swapchain", app.allocator);
        rg.global_render_graph.final_swapchain.init(@intCast(u32, width), @intCast(u32, height)) catch @panic("Error during swapchain creation");

        self.createSyncObjects() catch @panic("Can't create sync objects");

        for (rg.global_render_graph.passes.items) |pass|
            pass.initFn(pass);
    }

    fn systemDeinit(system: *System) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        for (rg.global_render_graph.passes.items) |pass|
            pass.deinitFn(pass);

        self.destroySyncObjects();
        rg.global_render_graph.final_swapchain.deinit();

        vkc.deinit();
    }

    fn systemUpdate(system: *System, elapsed_time: f64) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.render(elapsed_time) catch @panic("Error during rendering");
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
            self.image_available_semaphores[i] = vkd.createSemaphore(vkc.device, semaphore_info, null) catch |err| {
                printVulkanError("Can't create semaphore", err, self.allocator);
                return err;
            };
            self.render_finished_semaphores[i] = vkd.createSemaphore(vkc.device, semaphore_info, null) catch |err| {
                printVulkanError("Can't create semaphore", err, self.allocator);
                return err;
            };
            self.in_flight_fences[i] = vkd.createFence(vkc.device, fence_info, null) catch |err| {
                printVulkanError("Can't create fence", err, self.allocator);
                return err;
            };
        }
    }

    fn destroySyncObjects(self: *DefaultRenderer) void {
        var i: usize = 0;
        while (i < frames_in_flight) : (i += 1) {
            vkd.destroySemaphore(vkc.device, self.image_available_semaphores[i], null);
            vkd.destroySemaphore(vkc.device, self.render_finished_semaphores[i], null);
            vkd.destroyFence(vkc.device, self.in_flight_fences[i], null);
        }
    }

    fn recreateSwapchain(self: *DefaultRenderer) !void {
        var width: c_int = undefined;
        var height: c_int = undefined;
        while (width <= 0 or height <= 0) {
            c.glfwGetFramebufferSize(self.app.window, &width, &height);
            c.glfwWaitEvents();
        }

        vkd.deviceWaitIdle(vkc.device) catch |err| {
            printVulkanError("Can't wait for device idle while recreating swapchain", err, self.allocator);
            return err;
        };
        try rg.global_render_graph.final_swapchain.recreate(@intCast(u32, width), @intCast(u32, height));
    }

    fn render(self: *DefaultRenderer, elapsed_time: f64) !void {
        _ = vkd.waitForFences(vkc.device, 1, @ptrCast([*]const vk.Fence, &self.in_flight_fences[rg.global_render_graph.frame_index]), vk.TRUE, std.math.maxInt(u64)) catch |err| {
            printVulkanError("Can't wait for a in flight fence", err, self.allocator);
            return err;
        };

        var image_index: u32 = undefined;
        const vkres_acquire: vk.Result = vkd.vkAcquireNextImageKHR(
            vkc.device,
            rg.global_render_graph.final_swapchain.swapchain,
            std.math.maxInt(u64),
            self.image_available_semaphores[rg.global_render_graph.frame_index],
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

        var command_buffer: vk.CommandBuffer = self.renderFns.items[0](self.renderCtx.items[0], image_index);

        const wait_stage: vk.PipelineStageFlags = .{ .color_attachment_output_bit = true };
        const submit_info: vk.SubmitInfo = .{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]vk.Semaphore, &self.image_available_semaphores[rg.global_render_graph.frame_index]),
            .p_wait_dst_stage_mask = @ptrCast([*]const vk.PipelineStageFlags, &wait_stage),

            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast([*]vk.CommandBuffer, &command_buffer),

            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast([*]vk.Semaphore, &self.render_finished_semaphores[rg.global_render_graph.frame_index]),
        };

        vkd.resetFences(vkc.device, 1, @ptrCast([*]vk.Fence, &self.in_flight_fences[rg.global_render_graph.frame_index])) catch |err| {
            printVulkanError("Can't reset in flight fence", err, self.allocator);
            return err;
        };

        vkd.queueSubmit(vkc.graphics_queue, 1, @ptrCast([*]const vk.SubmitInfo, &submit_info), self.in_flight_fences[rg.global_render_graph.frame_index]) catch |err| {
            printVulkanError("Can't submit render queue", err, vkc.allocator);
        };

        const present_info: vk.PresentInfoKHR = .{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]vk.Semaphore, &self.render_finished_semaphores[rg.global_render_graph.frame_index]),

            .swapchain_count = 1,
            .p_swapchains = @ptrCast([*]vk.SwapchainKHR, &rg.global_render_graph.final_swapchain.swapchain),
            .p_image_indices = @ptrCast([*]const u32, &image_index),

            .p_results = null,
        };

        const vkres_present = vkd.vkQueuePresentKHR(vkc.present_queue, &present_info);
        if (vkres_present == .error_out_of_date_khr or vkres_present == .suboptimal_khr) {
            try self.recreateSwapchain();
        } else if (vkres_present != .success) {
            printError("Vulkan Wrapper", "Can't queue present");
            return error.Unknown;
        }

        rg.global_render_graph.frame_index = (rg.global_render_graph.frame_index + 1) % frames_in_flight;
    }
};
