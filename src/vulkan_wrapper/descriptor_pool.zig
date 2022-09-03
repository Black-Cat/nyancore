const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const DescriptorPool = struct {
    vk_ref: vk.DescriptorPool,

    pub fn init(self: *DescriptorPool, pool_sizes: []const vk.DescriptorPoolSize, max_sets: u32) void {
        const descriptor_pool_info: vk.DescriptorPoolCreateInfo = .{
            .pool_size_count = @intCast(u32, pool_sizes.len),
            .p_pool_sizes = @ptrCast([*]const vk.DescriptorPoolSize, pool_sizes.ptr),
            .max_sets = max_sets,
            .flags = .{},
        };

        self.vk_ref = vkfn.d.createDescriptorPool(vkctxt.device, descriptor_pool_info, null) catch |err| {
            printVulkanError("Can't create descriptor pool", err);
            return;
        };
    }

    pub fn deinit(self: *DescriptorPool) void {
        vkfn.d.destroyDescriptorPool(vkctxt.device, self.vk_ref, null);
    }
};
