const std = @import("std");

const c = @import("../c.zig");
const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const Buffer = struct {
    pub const MemoryUsage = enum(c_uint) {
        gpu_lazily_allocated = c.VMA_MEMORY_USAGE_GPU_LAZILY_ALLOCATED,
        auto = c.VMA_MEMORY_USAGE_AUTO,
        auto_prefer_device = c.VMA_MEMORY_USAGE_AUTO_PREFER_DEVICE,
        auto_prefer_host = c.VMA_MEMORY_USAGE_AUTO_PREFER_HOST,
    };

    pub const MappingUsage = enum(c.VmaAllocationCreateFlagBits) {
        no_mapping = 0,
        sequential = c.VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT,
        random = c.VMA_ALLOCATION_CREATE_HOST_ACCESS_RANDOM_BIT,
    };

    vk_ref: vk.Buffer,
    allocation: c.VmaAllocation,
    allocation_info: c.VmaAllocationInfo,
    mapped_memory: *anyopaque,

    usage: vk.BufferUsageFlags,
    mapping_usage: MappingUsage,

    pub fn init(self: *Buffer, size: vk.DeviceSize, usage: vk.BufferUsageFlags, mapping_usage: MappingUsage) void {
        std.debug.assert(size != 0); // Vulkan doesn't allow zero size buffers

        self.usage = usage;
        self.mapping_usage = mapping_usage;

        const buffer_info: vk.BufferCreateInfo = .{
            .size = size,
            .usage = usage,
            .sharing_mode = .exclusive,
            .flags = .{},
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        const mapping_flags: c.VmaAllocationCreateFlagBits = if (mapping_usage == .no_mapping) 0 else c.VMA_ALLOCATION_CREATE_MAPPED_BIT;

        var vmaalloc_info: c.VmaAllocationCreateInfo = std.mem.zeroes(c.VmaAllocationCreateInfo);
        vmaalloc_info.usage = @enumToInt(MemoryUsage.auto);
        vmaalloc_info.flags = @enumToInt(mapping_usage) | mapping_flags;

        const vk_res = c.vmaCreateBuffer(
            vkctxt.vma_allocator,
            @ptrCast([*]const c.VkBufferCreateInfo, &buffer_info),
            &vmaalloc_info,
            @ptrCast([*c]?*c.VkBuffer_T, &self.vk_ref),
            &self.allocation,
            &self.allocation_info,
        );
        if (vk_res != c.VK_SUCCESS)
            printVulkanError("Can't allocate buffer", error.Unknown);

        if (mapping_usage != .no_mapping)
            self.mapped_memory = self.allocation_info.pMappedData.?;
    }

    pub fn flushWhole(self: *Buffer) void {
        const res = c.vmaFlushAllocation(vkctxt.vma_allocator, self.allocation, 0, vk.WHOLE_SIZE);
        if (res != c.VK_SUCCESS)
            printVulkanError("Can't flush buffer", error.Unknown);
    }

    pub fn destroy(self: *Buffer) void {
        vkfn.d.vkDestroyBuffer(vkctxt.device, self.vk_ref, null);
        c.vmaFreeMemory(vkctxt.vma_allocator, self.allocation);
    }

    pub fn resize(self: *Buffer, new_size: vk.DeviceSize) void {
        self.destroy();
        self.init(new_size, self.usage, self.mapping_usage);
    }
};
