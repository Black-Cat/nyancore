const std = @import("std");
const vk = @import("../../vk.zig");

const vkctxt = @import("../../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../../vulkan_wrapper/vulkan_functions.zig");

const printError = @import("../../application/print_error.zig").printError;
const printVulkanError = @import("../../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const RGPass = @import("render_graph_pass.zig").RGPass;
const PassList = std.ArrayList(*RGPass);
const RGResource = @import("render_graph_resource.zig").RGResource;
const ResourceList = std.ArrayList(*RGResource);
const ResourceMap = std.AutoArrayHashMap(*anyopaque, *RGResource);

const SyncPass = @import("passes/sync_pass.zig").SyncPass;
const Swapchain = @import("../../vulkan_wrapper/swapchain.zig").Swapchain;
const CommandPool = @import("../../vulkan_wrapper/command_pool.zig").CommandPool;
const CommandBuffer = @import("../../vulkan_wrapper/command_buffer.zig").CommandBuffer;

pub var global_render_graph: RenderGraph = undefined;

pub const RenderGraph = struct {
    pub const ResourceChangeFn = struct {
        res: *RGResource,
        change_fn: *const fn (res: *RGResource) void,
    };

    allocator: std.mem.Allocator,

    final_swapchain: Swapchain,
    needs_rebuilding: bool,

    command_pools: []CommandPool,
    compute_command_pools: []CommandPool,

    frame_index: u32,
    image_index: u32,
    in_flight: u32,

    passes: PassList,
    resources: ResourceMap,

    culled_passes: PassList,
    culled_resources: ResourceList,

    sorted_passes: PassList,
    sync_passes: std.ArrayList(*SyncPass),

    resource_changes: std.ArrayList(ResourceChangeFn),

    pub fn init(self: *RenderGraph, allocator: std.mem.Allocator) void {
        self.allocator = allocator;

        self.passes = PassList.init(allocator);
        self.resources = ResourceMap.init(allocator);

        self.culled_passes = PassList.init(allocator);
        self.culled_resources = ResourceList.init(allocator);

        self.sorted_passes = PassList.init(allocator);
        self.sync_passes = std.ArrayList(*SyncPass).init(allocator);

        self.resource_changes = std.ArrayList(ResourceChangeFn).init(allocator);

        self.frame_index = 0;
        self.image_index = 0;
        self.needs_rebuilding = false;

        // Swapchain is not initialized but we already know pointer
        self.addResource(&self.final_swapchain, "Final Swapchain");
    }

    pub fn initVulkan(self: *RenderGraph, in_flight: u32) void {
        self.in_flight = in_flight;

        self.command_pools = vkctxt.allocator.alloc(CommandPool, in_flight) catch unreachable;
        for (self.command_pools) |*cp| {
            cp.* = CommandPool.create(vkctxt.physical_device.family_indices.graphics_family) catch |err| {
                printVulkanError("Can't create command pool for render graph", err);
                return;
            };

            cp.allocateBuffers(1); // Main buffer
        }

        self.compute_command_pools = vkctxt.allocator.alloc(CommandPool, in_flight) catch unreachable;
        for (self.compute_command_pools) |*cp| {
            cp.* = CommandPool.create(vkctxt.physical_device.family_indices.compute_family) catch |err| {
                printVulkanError("Can't create compute command pool for render graph", err);
                return;
            };
            cp.allocateBuffers(1); // Main buffer
        }
    }

    pub fn deinitCommandBuffers(self: *RenderGraph) void {
        vkfn.d.deviceWaitIdle(vkctxt.device) catch |err| {
            printVulkanError("Can't wait for device idle while destruction of command buffers", err);
        };

        for (self.command_pools) |*cp| {
            cp.freeBuffers();
            cp.destroy();
        }
        vkctxt.allocator.free(self.command_pools);

        for (self.compute_command_pools) |*cp| {
            cp.freeBuffers();
            cp.destroy();
        }
        vkctxt.allocator.free(self.compute_command_pools);
    }

    pub fn deinit(self: *RenderGraph) void {
        self.passes.deinit();

        for (self.resources.values()) |res| {
            res.deinit();
            self.allocator.destroy(res);
        }
        self.resources.deinit();

        self.culled_passes.deinit();
        self.culled_resources.deinit();

        self.sorted_passes.deinit();
        self.sync_passes.deinit();
    }

    pub fn addResource(self: *RenderGraph, res: *anyopaque, name: []const u8) void {
        var rg_res: *RGResource = self.allocator.create(RGResource) catch unreachable;
        rg_res.init(name, self.allocator);
        self.resources.put(res, rg_res) catch unreachable;
    }

    pub fn getResource(self: *RenderGraph, res: *anyopaque) *RGResource {
        return self.resources.get(res).?;
    }

    pub fn changeResourceBetweenFrames(self: *RenderGraph, res: *RGResource, change_fn: *const fn (res: *RGResource) void) void {
        const fn_cxt: ResourceChangeFn = .{
            .res = res,
            .change_fn = change_fn,
        };
        self.resource_changes.append(fn_cxt) catch unreachable;
    }

    pub fn hasResourceChanges(self: *RenderGraph) bool {
        return self.resource_changes.items.len != 0;
    }

    pub fn executeResourceChanges(self: *RenderGraph) void {
        for (self.resource_changes.items) |ctx|
            ctx.change_fn(ctx.res);

        self.resource_changes.clearRetainingCapacity();
    }

    pub fn build(self: *RenderGraph) void {
        self.cull();
        updateSyncPasses(self.culled_passes, self.culled_resources, &self.sync_passes);
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

        const final_swapchain_res: *RGResource = self.getResource(&self.final_swapchain);
        queue_resources.append(final_swapchain_res) catch unreachable;

        while (queue_resources.items.len > 0 or queue_passes.items.len > 0) {
            if (queue_resources.items.len > 0) {
                const res: *RGResource = queue_resources.pop();
                for (res.writers.items) |w| {
                    if (visited.get(w) != null)
                        continue;

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

    fn updateSyncPasses(passes: PassList, resources: ResourceList, sync_passes: *std.ArrayList(*SyncPass)) void {
        for (passes.items) |pass| {
            const is_culled: bool = !(for (resources.items) |res| {
                if (res == &pass.sync_point.rg_resource) break true;
            } else false);

            if (is_culled)
                continue;

            const sync_pass: ?*SyncPass = for (sync_passes.items) |sp| {
                if (&sp.rg_pass == pass)
                    break sp;
            } else null;

            if (sync_pass == null)
                continue;

            var barrier_start: u32 = vk.PipelineStageFlags.toInt(.{ .top_of_pipe_bit = true });
            var barrier_end: u32 = vk.PipelineStageFlags.toInt(.{ .bottom_of_pipe_bit = true });

            for (sync_pass.?.input_sync_point.rg_resource.writers.items) |synced_pass|
                barrier_end = @max(barrier_end, vk.PipelineStageFlags.toInt(synced_pass.pipeline_end));

            for (sync_pass.?.output_sync_point.rg_resource.readers.items) |synced_pass|
                barrier_end = @min(barrier_end, vk.PipelineStageFlags.toInt(synced_pass.pipeline_start));

            sync_pass.?.rg_pass.pipeline_start = vk.PipelineStageFlags.fromInt(barrier_start);
            sync_pass.?.rg_pass.pipeline_end = vk.PipelineStageFlags.fromInt(barrier_end);
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

    pub fn render(self: *RenderGraph, command_buffer: *CommandBuffer) void {
        for (self.sorted_passes.items) |rp|
            rp.renderFn(rp, command_buffer, self.frame_index);
    }

    pub fn initPasses(self: *RenderGraph) void {
        for (self.passes.items) |pass|
            pass.initFn(pass);

        self.build();
    }

    pub fn getCurrentCommandPool(self: *RenderGraph) *CommandPool {
        return &self.command_pools[self.frame_index];
    }

    pub fn deleteResource(self: *RenderGraph, res: *RGResource, deleteFn: *const fn (res: *RGResource) void) void {
        res.deinit();

        for (self.resources.values(), self.resources.keys()) |v, k| {
            if (v == res) {
                self.resources.swapRemove(k);
                break;
            }
        }

        self.changeResourceBetweenFrames(res, deleteFn);
    }
};
