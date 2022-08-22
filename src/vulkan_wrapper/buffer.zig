const std = @import("std");

const c = @import("../c.zig");
const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const VmaAllocation = @import("vma_allocation.zig").VmaAllocation;

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const Buffer = struct {
    vk_ref: vk.Buffer,

    allocation: VmaAllocation,

    usage: vk.BufferUsageFlags,

    pub fn init(self: *Buffer, size: vk.DeviceSize, usage: vk.BufferUsageFlags, mapping_usage: VmaAllocation.MappingUsage) void {
        std.debug.assert(size != 0); // Vulkan doesn't allow zero size buffers

        self.usage = usage;

        const buffer_info: vk.BufferCreateInfo = .{
            .size = size,
            .usage = usage,
            .sharing_mode = .exclusive,
            .flags = .{},
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        self.allocation = .{
            .mapping_usage = mapping_usage,
        };

        self.allocation.create(buffer_info, &self.vk_ref);
    }

    pub fn flushWhole(self: *Buffer) void {
        self.allocation.flushWhole();
    }

    pub fn destroy(self: *Buffer) void {
        vkfn.d.vkDestroyBuffer(vkctxt.device, self.vk_ref, null);
        self.allocation.free();
    }

    pub fn resize(self: *Buffer, new_size: vk.DeviceSize) void {
        self.destroy();
        self.init(new_size, self.usage, self.allocation.mapping_usage);
    }
};
