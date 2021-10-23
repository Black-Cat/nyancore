const std = @import("std");
const vk = @import("../../vk.zig");

usingnamespace @import("resources/resources.zig");
usingnamespace @import("../../vulkan_wrapper/vulkan_wrapper.zig");

const printError = @import("../../application/print_error.zig").printError;

const RGPass = @import("render_graph_pass.zig").RGPass;
const PassList = std.ArrayList(*RGPass);
const RGResource = @import("render_graph_resource.zig").RGResource;
const ResourceList = std.ArrayList(*RGResource);

pub var global_render_graph: RenderGraph = undefined;

pub const RenderGraph = struct {
    pub const ResourceChangeFn = struct {
        res: *RGResource,
        change_fn: fn (res: *RGResource) void,
    };

    allocator: *std.mem.Allocator,

    final_swapchain: Swapchain,
    needs_rebuilding: bool,

    command_pool: vk.CommandPool,
    command_buffers: []vk.CommandBuffer,

    frame_index: u32,
    image_index: u32,
    in_flight: u32,

    passes: PassList,
    resources: ResourceList,

    culled_passes: PassList,
    culled_resources: ResourceList,

    sorted_passes: PassList,

    resource_changes: std.ArrayList(ResourceChangeFn),

    textures: std.ArrayList(*Texture),
    viewport_textures: std.ArrayList(*ViewportTexture),

    pub fn init(self: *RenderGraph, allocator: *std.mem.Allocator) void {
        self.allocator = allocator;

        self.passes = PassList.init(allocator);
        self.resources = ResourceList.init(allocator);

        self.culled_passes = PassList.init(allocator);
        self.culled_resources = ResourceList.init(allocator);

        self.sorted_passes = PassList.init(allocator);

        self.resource_changes = std.ArrayList(ResourceChangeFn).init(allocator);

        self.textures = std.ArrayList(*Texture).init(allocator);
        self.viewport_textures = std.ArrayList(*ViewportTexture).init(allocator);

        self.frame_index = 0;
        self.image_index = 0;
        self.needs_rebuilding = false;
    }

    pub fn initVulkan(self: *RenderGraph) void {
        self.in_flight = self.final_swapchain.image_count;

        const pool_info: vk.CommandPoolCreateInfo = .{
            .queue_family_index = vkc.family_indices.graphics_family,
            .flags = .{
                .reset_command_buffer_bit = true,
            },
        };

        self.command_pool = vkd.createCommandPool(vkc.device, pool_info, null) catch |err| {
            printVulkanError("Can't create command pool for render graph", err, vkc.allocator);
            return;
        };

        const command_buffer_info: vk.CommandBufferAllocateInfo = .{
            .level = .primary,
            .command_pool = self.command_pool,
            .command_buffer_count = self.in_flight,
        };

        self.command_buffers = self.allocator.alloc(vk.CommandBuffer, self.in_flight) catch unreachable;

        vkd.allocateCommandBuffers(vkc.device, command_buffer_info, self.command_buffers.ptr) catch |err| {
            printVulkanError("Can't allocate primary command buffers", err, vkc.allocator);
        };
    }

    pub fn deinit(self: *RenderGraph) void {
        vkd.freeCommandBuffers(vkc.device, self.command_pool, self.in_flight, self.command_buffers.ptr);
        vkd.destroyCommandPool(vkc.device, self.command_pool, null);

        self.passes.deinit();
        self.resources.deinit();

        self.culled_passes.deinit();
        self.culled_resources.deinit();

        self.sorted_passes.deinit();

        self.allocator.free(self.command_buffers);
    }

    pub fn addTexture(self: *RenderGraph, tex: *Texture) void {
        self.textures.append(tex) catch unreachable;
        self.resources.append(&tex.rg_resource) catch unreachable;
    }

    pub fn addViewportTexture(self: *RenderGraph, tex: *ViewportTexture) void {
        self.viewport_textures.append(tex) catch unreachable;
        self.resources.append(&tex.rg_resource) catch unreachable;
    }

    pub fn removeTexture(self: *RenderGraph, tex: *Texture) void {}

    pub fn changeResourceBetweenFrames(self: *RenderGraph, res: *RGResource, change_fn: fn (res: *RGResource) void) void {
        const fn_cxt: ResourceChangeFn = .{
            .res = res,
            .change_fn = change_fn,
        };
        self.resource_changes.append(fn_cxt) catch unreachable;
    }

    pub fn executeResourceChanges(self: *RenderGraph) void {
        if (self.resource_changes.items.len == 0)
            return;

        vkd.deviceWaitIdle(vkc.device) catch |err| {
            printVulkanError("Can't wait for device idle in order to change resources", err, vkc.allocator);
            return;
        };

        for (self.resource_changes.items) |ctx|
            ctx.change_fn(ctx.res);

        for (self.resource_changes.items) |ctx|
            for (ctx.res.on_change_callbacks.items) |cb|
                cb.callback(cb.pass);

        self.resource_changes.clearRetainingCapacity();
    }

    pub fn build(self: *RenderGraph) void {
        self.cull();
        self.topology_sort();

        self.needs_rebuilding = false;
    }

    fn cull(self: *RenderGraph) void {
        self.culled_passes.clearRetainingCapacity();
        self.culled_resources.clearRetainingCapacity();

        var queue_passes: std.ArrayList(*RGPass) = std.ArrayList(*RGPass).init(self.allocator);
        defer queue_passes.deinit();

        var queue_resources: std.ArrayList(*RGResource) = std.ArrayList(*RGResource).init(self.allocator);
        defer queue_resources.deinit();

        var visited: std.AutoHashMap(*RGPass, bool) = std.AutoHashMap(*RGPass, bool).init(self.allocator);
        defer visited.deinit();

        queue_resources.append(&self.final_swapchain.rg_resource) catch unreachable;

        while (queue_resources.items.len > 0 or queue_passes.items.len > 0) {
            if (queue_resources.items.len > 0) {
                const res: *RGResource = queue_resources.pop();
                for (res.writers.items) |w| {
                    if (visited.get(w) != null) {
                        continue;
                    }

                    queue_passes.append(w) catch unreachable;
                    self.culled_passes.append(w) catch unreachable;
                    visited.put(w, true) catch unreachable;
                }
                continue;
            }

            const pass: *RGPass = queue_passes.pop();
            for (pass.reads_from.items) |r| {
                queue_resources.append(r) catch unreachable;
                self.culled_resources.append(r) catch unreachable;
            }
        }
    }

    // Uses culled lists
    fn topology_sort(self: *RenderGraph) void {
        self.sorted_passes.clearRetainingCapacity();

        var unready_passes: std.AutoArrayHashMap(*RGPass, usize) = std.AutoArrayHashMap(*RGPass, usize).init(self.allocator);
        defer unready_passes.deinit();

        unready_passes.ensureTotalCapacity(self.culled_passes.items.len) catch unreachable;

        for (self.culled_passes.items) |p| {
            var passes_before_count: usize = 0;
            for (p.reads_from.items) |r|
                passes_before_count += r.writers.items.len;
            unready_passes.putAssumeCapacity(p, passes_before_count);
        }

        while (unready_passes.count() > 0) {
            var it = unready_passes.iterator();
            const pass: *RGPass = while (it.next()) |kv| {
                if (kv.value_ptr.* == 0) {
                    break kv.key_ptr.*;
                }
            } else {
                printError("Render Graph", "Can't build graph: Cycle in graph");
                return;
            };

            self.sorted_passes.append(pass) catch unreachable;
            _ = unready_passes.swapRemove(pass);

            for (pass.writes_to.items) |res| {
                for (res.readers.items) |r| {
                    unready_passes.getPtr(r).?.* -= 1;
                }
            }
        }
    }

    pub fn render(self: *RenderGraph, command_buffer: vk.CommandBuffer, image_index: u32) void {
        for (self.sorted_passes.items) |rp|
            rp.renderFn(rp, command_buffer, image_index);
    }

    pub fn beginSingleTimeCommands(self: *RenderGraph, command_buffer: vk.CommandBuffer) void {
        const begin_info: vk.CommandBufferBeginInfo = .{
            .flags = .{
                .one_time_submit_bit = true,
            },
            .p_inheritance_info = undefined,
        };

        vkd.beginCommandBuffer(command_buffer, begin_info) catch |err| {
            printVulkanError("Can't begin command buffer", err, vkc.allocator);
        };
    }

    pub fn endSingleTimeCommands(self: *RenderGraph, command_buffer: vk.CommandBuffer) void {
        vkd.endCommandBuffer(command_buffer) catch |err| {
            printVulkanError("Can't end command buffer", err, vkc.allocator);
            return;
        };
    }

    // Pls don't use, created for special cases
    pub fn allocateCommandBuffer(self: *RenderGraph) vk.CommandBuffer {
        const alloc_info: vk.CommandBufferAllocateInfo = .{
            .level = .primary,
            .command_pool = self.command_pool,
            .command_buffer_count = 1,
        };

        var command_buffer: vk.CommandBuffer = undefined;
        vkd.allocateCommandBuffers(vkc.device, alloc_info, @ptrCast([*]vk.CommandBuffer, &command_buffer)) catch |err| {
            printVulkanError("Can't allocate command buffer", err, vkc.allocator);
        };
        return command_buffer;
    }

    // Pls don't use, created for special cases
    pub fn submitCommandBuffer(self: *RenderGraph, command_buffer: vk.CommandBuffer) void {
        const submit_info: vk.SubmitInfo = .{
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &command_buffer),
            .wait_semaphore_count = 0,
            .p_wait_semaphores = undefined,
            .p_wait_dst_stage_mask = undefined,
            .signal_semaphore_count = 0,
            .p_signal_semaphores = undefined,
        };

        vkd.queueSubmit(vkc.graphics_queue, 1, @ptrCast([*]const vk.SubmitInfo, &submit_info), .null_handle) catch |err| {
            printVulkanError("Can't submit queue", err, vkc.allocator);
        };
        vkd.queueWaitIdle(vkc.graphics_queue) catch |err| {
            printVulkanError("Can't wait for queue", err, vkc.allocator);
        };

        vkd.freeCommandBuffers(vkc.device, self.command_pool, 1, @ptrCast([*]const vk.CommandBuffer, &command_buffer));
    }
};
