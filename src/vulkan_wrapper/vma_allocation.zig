const std = @import("std");

const c = @import("../c.zig");
const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const VmaAllocation = struct {
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

    allocation: c.VmaAllocation = undefined,
    allocation_info: c.VmaAllocationInfo = undefined,

    usage: MemoryUsage = .auto,
    mapping_usage: MappingUsage = .no_mapping,

    mapped_memory: *anyopaque = undefined,

    pub fn create(self: *VmaAllocation, creation_info: anytype, vk_ref: *anyopaque) void {
        const mapping_flags: c.VmaAllocationCreateFlagBits = if (self.mapping_usage == .no_mapping) 0 else c.VMA_ALLOCATION_CREATE_MAPPED_BIT;

        var vmaalloc_info: c.VmaAllocationCreateInfo = std.mem.zeroes(c.VmaAllocationCreateInfo);
        vmaalloc_info.usage = @intFromEnum(MemoryUsage.auto);
        vmaalloc_info.flags = @intFromEnum(self.mapping_usage) | mapping_flags;

        const vk_res = switch (@TypeOf(creation_info)) {
            vk.BufferCreateInfo => c.vmaCreateBuffer(
                vkctxt.vma_allocator,
                @ptrCast(&creation_info),
                &vmaalloc_info,
                @ptrCast(@alignCast(vk_ref)),
                &self.allocation,
                &self.allocation_info,
            ),
            vk.ImageCreateInfo => c.vmaCreateImage(
                vkctxt.vma_allocator,
                @ptrCast(&creation_info),
                &vmaalloc_info,
                @ptrCast(@alignCast(vk_ref)),
                &self.allocation,
                &self.allocation_info,
            ),
            else => @compileError("Unsupported creation info type " ++ @typeName(@TypeOf(creation_info)) ++
                ". Only vk.BufferCreateInfo and vk.ImageCreateInfo are supported"),
        };

        if (vk_res != c.VK_SUCCESS)
            printVulkanError("Can't allocate " ++ if (@TypeOf(creation_info) == vk.BufferCreateInfo) "buffer" else "image", error.Unknown);

        if (self.mapping_usage != .no_mapping)
            self.mapped_memory = self.allocation_info.pMappedData.?;
    }

    pub fn free(self: *VmaAllocation) void {
        c.vmaFreeMemory(vkctxt.vma_allocator, self.allocation);
    }

    pub fn flushWhole(self: *VmaAllocation) void {
        const res = c.vmaFlushAllocation(vkctxt.vma_allocator, self.allocation, 0, vk.WHOLE_SIZE);
        if (res != c.VK_SUCCESS)
            printVulkanError("Can't flush vma memory", error.Unknown);
    }
};
