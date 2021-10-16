const std = @import("std");

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

    pub fn init(self: *RenderGraph, in_flight: u32, allocator: *std.mem.Allocator) void {
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
        self.in_flight = in_flight;
        self.needs_rebuilding = false;
    }

    pub fn deinit(self: *RenderGraph) void {
        self.passes.deinit();
        self.resources.deinit();

        self.culled_passes.deinit();
        self.culled_resources.deinit();

        self.sorted_passes.deinit();
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

        for (self.culled_passes.items) |p, ind|
            unready_passes.putAssumeCapacity(p, p.reads_from.items.len);

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
};
