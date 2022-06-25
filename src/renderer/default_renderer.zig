const std = @import("std");
const vk = @import("../vk.zig");
const c = @import("../c.zig");
const tracy = @import("../tracy.zig");

const vkctxt = @import("../vulkan_wrapper/vulkan_context.zig");

const Allocator = std.mem.Allocator;
const Application = @import("../application/application.zig").Application;
pub const System = @import("../system/system.zig").System;

const rg = @import("render_graph/render_graph.zig");
const RenderGraph = rg.RenderGraph;
const RGPass = @import("render_graph/render_graph_pass.zig").RGPass;
const RGResource = @import("render_graph/render_graph_resource.zig").RGResource;

const printError = @import("../application/print_error.zig").printError;
const printVulkanError = @import("../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const frames_in_flight: u32 = 2;

pub const DefaultRenderer = struct {
    allocator: Allocator,
    name: []const u8,
    system: System,
    app: *Application,

    image_available_semaphores: [frames_in_flight]vk.Semaphore,
    render_finished_semaphores: [frames_in_flight]vk.Semaphore,
    in_flight_fences: [frames_in_flight]vk.Fence,

    framebuffer_resized: bool,

    pub fn init(self: *DefaultRenderer, comptime name: []const u8, allocator: Allocator) void {
        self.allocator = allocator;
        self.name = name;
        self.framebuffer_resized = false;

        self.system = System.create(name ++ " System", systemInit, systemDeinit, systemUpdate);

        rg.global_render_graph.init(self.allocator);

        rg.global_render_graph.final_swapchain.rg_resource.init("Final Swapchain", self.allocator);
    }

    fn systemInit(system: *System, app: *Application) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.app = app;

        vkctxt.vkc.init(self.allocator, app) catch @panic("Error during vulkan context initialization");

        var width: i32 = undefined;
        var height: i32 = undefined;
        c.glfwGetFramebufferSize(app.window, &width, &height);

        rg.global_render_graph.final_swapchain.init(@intCast(u32, width), @intCast(u32, height), frames_in_flight) catch @panic("Error during swapchain creation");

        rg.global_render_graph.initVulkan(frames_in_flight);

        self.createSyncObjects() catch @panic("Can't create sync objects");
    }

    fn systemDeinit(system: *System) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        for (rg.global_render_graph.passes.items) |pass|
            pass.deinitFn(pass);

        self.destroySyncObjects();
        rg.global_render_graph.final_swapchain.deinit();
        rg.global_render_graph.deinit();

        vkctxt.vkc.deinit();
    }

    fn systemUpdate(system: *System, elapsed_time: f64) void {
        _ = elapsed_time;
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.render() catch @panic("Error during rendering");
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
            self.image_available_semaphores[i] = vkctxt.vkd.createSemaphore(vkctxt.vkc.device, semaphore_info, null) catch |err| {
                printVulkanError("Can't create semaphore", err);
                return err;
            };
            self.render_finished_semaphores[i] = vkctxt.vkd.createSemaphore(vkctxt.vkc.device, semaphore_info, null) catch |err| {
                printVulkanError("Can't create semaphore", err);
                return err;
            };
            self.in_flight_fences[i] = vkctxt.vkd.createFence(vkctxt.vkc.device, fence_info, null) catch |err| {
                printVulkanError("Can't create fence", err);
                return err;
            };
        }
    }

    fn destroySyncObjects(self: *DefaultRenderer) void {
        var i: usize = 0;
        while (i < frames_in_flight) : (i += 1) {
            vkctxt.vkd.destroySemaphore(vkctxt.vkc.device, self.image_available_semaphores[i], null);
            vkctxt.vkd.destroySemaphore(vkctxt.vkc.device, self.render_finished_semaphores[i], null);
            vkctxt.vkd.destroyFence(vkctxt.vkc.device, self.in_flight_fences[i], null);
        }
    }

    fn recreateSwapchain(self: *DefaultRenderer) !void {
        var width: c_int = undefined;
        var height: c_int = undefined;
        while (width <= 0 or height <= 0) {
            c.glfwGetFramebufferSize(self.app.window, &width, &height);
            c.glfwWaitEvents();
        }

        try rg.global_render_graph.final_swapchain.recreate(@intCast(u32, width), @intCast(u32, height));
    }

    fn render(self: *DefaultRenderer) !void {
        _ = vkctxt.vkd.waitForFences(vkctxt.vkc.device, 1, @ptrCast([*]const vk.Fence, &self.in_flight_fences[rg.global_render_graph.frame_index]), vk.TRUE, std.math.maxInt(u64)) catch |err| {
            printVulkanError("Can't wait for a in flight fence", err);
            return err;
        };

        var image_index: u32 = undefined;
        const vkres_acquire: vk.Result = vkctxt.vkd.vkAcquireNextImageKHR(
            vkctxt.vkc.device,
            rg.global_render_graph.final_swapchain.swapchain,
            std.math.maxInt(u64),
            self.image_available_semaphores[rg.global_render_graph.frame_index],
            .null_handle,
            &image_index,
        );
        rg.global_render_graph.image_index = image_index;

        if (vkres_acquire == .error_out_of_date_khr) {
            try self.recreateSwapchain();
            return;
        } else if (vkres_acquire != .success and vkres_acquire != .suboptimal_khr) {
            printError("Renderer", "Error while getting swapchain image");
            return error.Unknown;
        }

        var command_buffer: vk.CommandBuffer = rg.global_render_graph.command_buffers[rg.global_render_graph.frame_index];
        vkctxt.vkd.resetCommandBuffer(command_buffer, .{}) catch |err| {
            printVulkanError("Can't reset command buffer", err);
        };

        RenderGraph.beginSingleTimeCommands(command_buffer);
        rg.global_render_graph.render(command_buffer);
        RenderGraph.endSingleTimeCommands(command_buffer);

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

        vkctxt.vkd.resetFences(vkctxt.vkc.device, 1, @ptrCast([*]vk.Fence, &self.in_flight_fences[rg.global_render_graph.frame_index])) catch |err| {
            printVulkanError("Can't reset in flight fence", err);
            return err;
        };

        vkctxt.vkd.queueSubmit(vkctxt.vkc.graphics_queue, 1, @ptrCast([*]const vk.SubmitInfo, &submit_info), self.in_flight_fences[rg.global_render_graph.frame_index]) catch |err| {
            printVulkanError("Can't submit render queue", err);
        };

        const present_info: vk.PresentInfoKHR = .{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]vk.Semaphore, &self.render_finished_semaphores[rg.global_render_graph.frame_index]),

            .swapchain_count = 1,
            .p_swapchains = @ptrCast([*]vk.SwapchainKHR, &rg.global_render_graph.final_swapchain.swapchain),
            .p_image_indices = @ptrCast([*]const u32, &image_index),

            .p_results = null,
        };

        const vkres_present = vkctxt.vkd.vkQueuePresentKHR(vkctxt.vkc.present_queue, &present_info);
        if (vkres_present == .error_out_of_date_khr or vkres_present == .suboptimal_khr) {
            try self.recreateSwapchain();
        } else if (vkres_present != .success) {
            printError("Vulkan Wrapper", "Can't queue present");
            return error.Unknown;
        }

        rg.global_render_graph.frame_index = (rg.global_render_graph.frame_index + 1) % frames_in_flight;

        rg.global_render_graph.executeResourceChanges();
        if (rg.global_render_graph.needs_rebuilding)
            rg.global_render_graph.build();
    }
};
