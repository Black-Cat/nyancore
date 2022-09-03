const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const DescriptorSetLayout = struct {
    vk_ref: vk.DescriptorSetLayout,

    pub fn init(self: *DescriptorSetLayout, bindings: []const vk.DescriptorSetLayoutBinding) void {
        const set_layout_create_info: vk.DescriptorSetLayoutCreateInfo = .{
            .binding_count = @intCast(u32, bindings.len),
            .p_bindings = @ptrCast([*]const vk.DescriptorSetLayoutBinding, bindings.ptr),
            .flags = .{},
        };

        self.vk_ref = vkfn.d.createDescriptorSetLayout(vkctxt.device, set_layout_create_info, null) catch |err| {
            printVulkanError("Can't create descriptor set layout", err);
            return;
        };
    }

    pub fn deinit(self: *DescriptorSetLayout) void {
        vkfn.d.destroyDescriptorSetLayout(vkctxt.device, self.vk_ref, null);
    }
};
