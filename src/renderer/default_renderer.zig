const std = @import("std");
const vk = @import("../vk.zig");
const c = @import("../c.zig");
const tracy = @import("../tracy.zig");

const vkctxt = @import("../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../vulkan_wrapper/vulkan_functions.zig");

const Allocator = std.mem.Allocator;
const Application = @import("../application/application.zig").Application;
pub const System = @import("../system/system.zig").System;

const rg = @import("render_graph/render_graph.zig");
const RenderGraph = rg.RenderGraph;
const RGPass = @import("render_graph/render_graph_pass.zig").RGPass;
const RGResource = @import("render_graph/render_graph_resource.zig").RGResource;
const CommandBuffer = @import("../vulkan_wrapper/command_buffer.zig").CommandBuffer;
const CommandPool = @import("../vulkan_wrapper/command_pool.zig").CommandPool;
const Fence = @import("../vulkan_wrapper/fence.zig").Fence;
const Semaphore = @import("../vulkan_wrapper/semaphore.zig").Semaphore;

const printError = @import("../application/print_error.zig").printError;
const printVulkanError = @import("../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const frames_in_flight: u32 = 2;

pub const DefaultRenderer = struct {
    allocator: Allocator,
    name: []const u8,
    system: System,
    app: *Application,

    image_available_semaphores: [frames_in_flight]Semaphore,
    render_finished_semaphores: [frames_in_flight]Semaphore,
    in_flight_fences: [frames_in_flight]Fence,

    framebuffer_resized: bool,

    pub fn init(self: *DefaultRenderer, comptime name: []const u8, allocator: Allocator) void {
        self.allocator = allocator;
        self.name = name;
        self.framebuffer_resized = false;

        self.system = System.create(name ++ " System", systemInit, systemDeinit, systemUpdate);

        rg.global_render_graph.init(self.allocator);

        @import("../vulkan_wrapper/shader_module.zig").initShaderCompilation();
    }

    fn systemInit(system: *System, app: *Application) void {
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.app = app;

        vkctxt.init(self.allocator, app) catch @panic("Error during vulkan context initialization");

        var width: i32 = undefined;
        var height: i32 = undefined;
        c.glfwGetFramebufferSize(app.window, &width, &height);

        const vsync: bool = app.config.getBool("swapchain_vsync");
        rg.global_render_graph.final_swapchain.init(
            @intCast(width),
            @intCast(height),
            frames_in_flight,
            vsync,
        ) catch @panic("Error during swapchain creation");
        rg.global_render_graph.addResource(&rg.global_render_graph.final_swapchain, "Final Swapchain");

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

        vkctxt.deinit();
    }

    fn systemUpdate(system: *System, elapsed_time: f64) void {
        _ = elapsed_time;
        const self: *DefaultRenderer = @fieldParentPtr(DefaultRenderer, "system", system);

        self.render() catch @panic("Error during rendering");
    }

    fn createSyncObjects(self: *DefaultRenderer) !void {
        var i: usize = 0;
        while (i < frames_in_flight) : (i += 1) {
            self.image_available_semaphores[i] = Semaphore.create();
            self.render_finished_semaphores[i] = Semaphore.create();
            self.in_flight_fences[i] = Fence.create();
        }
    }

    fn destroySyncObjects(self: *DefaultRenderer) void {
        var i: usize = 0;
        while (i < frames_in_flight) : (i += 1) {
            self.image_available_semaphores[i].destroy();
            self.render_finished_semaphores[i].destroy();
            self.in_flight_fences[i].destroy();
        }
    }

    fn recreateSwapchain(window: *c.GLFWwindow) !void {
        var width: c_int = undefined;
        var height: c_int = undefined;
        while (width <= 0 or height <= 0) {
            c.glfwGetFramebufferSize(window, &width, &height);
            c.glfwWaitEvents();
        }

        try rg.global_render_graph.final_swapchain.recreate(@intCast(width), @intCast(height));
    }

    fn acquireImage(window: *c.GLFWwindow, acquire_semaphore: *Semaphore) !u32 {
        var image_index: u32 = undefined;

        const vkres_acquire: vk.Result = vkfn.d.dispatch.vkAcquireNextImageKHR(
            vkctxt.device,
            rg.global_render_graph.final_swapchain.swapchain,
            std.math.maxInt(u64),
            acquire_semaphore.vk_ref,
            .null_handle,
            &image_index,
        );

        if (vkres_acquire == .error_out_of_date_khr) {
            try recreateSwapchain(window);
        } else if (vkres_acquire != .success and vkres_acquire != .suboptimal_khr) {
            printError("Renderer", "Error while getting swapchain image");
            return error.Unknown;
        }

        return image_index;
    }

    fn presentSwapchain(window: *c.GLFWwindow, wait_semaphore: *Semaphore) !void {
        const present_info: vk.PresentInfoKHR = .{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(&wait_semaphore.vk_ref),

            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&rg.global_render_graph.final_swapchain.swapchain),
            .p_image_indices = @ptrCast(&rg.global_render_graph.image_index),

            .p_results = null,
        };

        const present_result = vkfn.d.queuePresentKHR(vkctxt.present_queue, &present_info);

        if (present_result) |_| {} else |err| {
            if (err != error.OutOfDateKHR) {
                printVulkanError("Can't queue present", err);
                return err;
            }
        }

        const recreate = if (present_result) |res| res == .suboptimal_khr else |err| err == error.OutOfDateKHR;
        if (recreate)
            try recreateSwapchain(window);
    }

    fn render(self: *DefaultRenderer) !void {
        const current_fence: *Fence = &self.in_flight_fences[rg.global_render_graph.frame_index];
        current_fence.waitFor();

        const current_image_available_semaphore: *Semaphore = &self.image_available_semaphores[rg.global_render_graph.frame_index];

        rg.global_render_graph.image_index = try acquireImage(self.app.window, current_image_available_semaphore);

        var command_pool: *CommandPool = rg.global_render_graph.getCurrentCommandPool();
        command_pool.reset();

        var command_buffer: CommandBuffer = command_pool.getBuffer(0); // Grab main buffer

        command_buffer.beginSingleTimeCommands();
        rg.global_render_graph.render(&command_buffer);
        command_buffer.endSingleTimeCommands();

        const current_render_finished_semaphore: *Semaphore = &self.render_finished_semaphores[rg.global_render_graph.frame_index];

        const wait_stage: vk.PipelineStageFlags = .{ .color_attachment_output_bit = true };
        const submit_info: vk.SubmitInfo = .{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(&current_image_available_semaphore.vk_ref),
            .p_wait_dst_stage_mask = @ptrCast(&wait_stage),

            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&command_buffer.vk_ref),

            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast(&current_render_finished_semaphore.vk_ref),
        };

        current_fence.reset();

        vkfn.d.queueSubmit(vkctxt.graphics_queue, 1, @ptrCast(&submit_info), current_fence.vk_ref) catch |err| {
            printVulkanError("Can't submit render queue", err);
        };

        try presentSwapchain(self.app.window, current_render_finished_semaphore);

        rg.global_render_graph.frame_index = (rg.global_render_graph.frame_index + 1) % frames_in_flight;

        if (rg.global_render_graph.hasResourceChanges()) {
            for (self.in_flight_fences) |f|
                f.waitFor();
            rg.global_render_graph.executeResourceChanges();
        }

        if (rg.global_render_graph.needs_rebuilding)
            rg.global_render_graph.build();
    }
};
