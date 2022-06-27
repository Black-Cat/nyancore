const nyancore_options = @import("nyancore_options");
const c = @import("../c.zig");
const std = @import("std");
const vk = @import("../vk.zig");
const builtin = @import("builtin");
const vkfn = @import("vulkan_functions.zig");

const Allocator = std.mem.Allocator;
const Application = @import("../application/application.zig").Application;

const Instance = @import("instance.zig");
const PhysicalDevice = @import("physical_device.zig").PhysicalDevice;

const printError = @import("../application/print_error.zig").printError;
const printErrorNoPanic = @import("../application/print_error.zig").printErrorNoPanic;
const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
pub extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *c.GLFWwindow, alocation_callback: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;

pub const required_device_extensions: [1][:0]const u8 = [_][:0]const u8{
    "VK_KHR_swapchain",
};

pub const validation_layers: [1][:0]const u8 = [_][:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

pub const Buffer = struct {
    size: vk.DeviceSize,
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    mapped_memory: *anyopaque,

    pub fn init(self: *Buffer, size: vk.DeviceSize, usage: vk.BufferUsageFlags, properties: vk.MemoryPropertyFlags) void {
        const buffer_info: vk.BufferCreateInfo = .{
            .size = size,
            .usage = usage,
            .sharing_mode = .exclusive,
            .flags = .{},
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        self.buffer = vkd.createBuffer(device, buffer_info, null) catch |err| {
            printVulkanError("Can't create buffer for ui", err);
            return;
        };

        var mem_req: vk.MemoryRequirements = vkd.getBufferMemoryRequirements(device, self.buffer);

        const alloc_info: vk.MemoryAllocateInfo = .{
            .allocation_size = mem_req.size,
            .memory_type_index = getMemoryType(mem_req.memory_type_bits, properties),
        };

        self.memory = vkd.allocateMemory(device, alloc_info, null) catch |err| {
            printVulkanError("Can't allocate buffer for ui", err);
            return;
        };

        vkd.bindBufferMemory(device, self.buffer, self.memory, 0) catch |err| {
            printVulkanError("Can't bind buffer memory for ui", err);
            return;
        };

        self.mapped_memory = vkd.mapMemory(device, self.memory, 0, size, .{}) catch |err| {
            printVulkanError("Can't map memory for ui", err);
            return;
        } orelse return;
    }

    pub fn flush(self: *Buffer) void {
        const mapped_range: vk.MappedMemoryRange = .{
            .memory = self.memory,
            .offset = 0,
            .size = vk.WHOLE_SIZE,
        };

        vkd.flushMappedMemoryRanges(device, 1, @ptrCast([*]const vk.MappedMemoryRange, &mapped_range)) catch |err| {
            printVulkanError("Can't flush buffer for ui", err);
        };
    }

    pub fn destroy(self: *Buffer) void {
        vkd.unmapMemory(device, self.memory);
        vkd.destroyBuffer(device, self.buffer, null);
        vkd.freeMemory(device, self.memory, null);
    }
};

const DeviceDispatch = struct {
    vkAcquireNextImageKHR: vk.PfnAcquireNextImageKHR,
    vkAllocateCommandBuffers: vk.PfnAllocateCommandBuffers,
    vkAllocateDescriptorSets: vk.PfnAllocateDescriptorSets,
    vkAllocateMemory: vk.PfnAllocateMemory,
    vkBeginCommandBuffer: vk.PfnBeginCommandBuffer,
    vkBindBufferMemory: vk.PfnBindBufferMemory,
    vkBindImageMemory: vk.PfnBindImageMemory,
    vkCmdBeginRenderPass: vk.PfnCmdBeginRenderPass,
    vkCmdBindDescriptorSets: vk.PfnCmdBindDescriptorSets,
    vkCmdBindIndexBuffer: vk.PfnCmdBindIndexBuffer,
    vkCmdBindPipeline: vk.PfnCmdBindPipeline,
    vkCmdBindVertexBuffers: vk.PfnCmdBindVertexBuffers,
    vkCmdClearAttachments: vk.PfnCmdClearAttachments,
    vkCmdCopyBufferToImage: vk.PfnCmdCopyBufferToImage,
    vkCmdCopyImageToBuffer: vk.PfnCmdCopyImageToBuffer,
    vkCmdDispatch: vk.PfnCmdDispatch,
    vkCmdDraw: vk.PfnCmdDraw,
    vkCmdDrawIndexed: vk.PfnCmdDrawIndexed,
    vkCmdEndRenderPass: vk.PfnCmdEndRenderPass,
    vkCmdPipelineBarrier: vk.PfnCmdPipelineBarrier,
    vkCmdPushConstants: vk.PfnCmdPushConstants,
    vkCmdSetScissor: vk.PfnCmdSetScissor,
    vkCmdSetViewport: vk.PfnCmdSetViewport,
    vkCreateBuffer: vk.PfnCreateBuffer,
    vkCreateCommandPool: vk.PfnCreateCommandPool,
    vkCreateComputePipelines: vk.PfnCreateComputePipelines,
    vkCreateDescriptorPool: vk.PfnCreateDescriptorPool,
    vkCreateDescriptorSetLayout: vk.PfnCreateDescriptorSetLayout,
    vkCreateFence: vk.PfnCreateFence,
    vkCreateFramebuffer: vk.PfnCreateFramebuffer,
    vkCreateGraphicsPipelines: vk.PfnCreateGraphicsPipelines,
    vkCreateImage: vk.PfnCreateImage,
    vkCreateImageView: vk.PfnCreateImageView,
    vkCreatePipelineCache: vk.PfnCreatePipelineCache,
    vkCreatePipelineLayout: vk.PfnCreatePipelineLayout,
    vkCreateRenderPass: vk.PfnCreateRenderPass,
    vkCreateSampler: vk.PfnCreateSampler,
    vkCreateSemaphore: vk.PfnCreateSemaphore,
    vkCreateShaderModule: vk.PfnCreateShaderModule,
    vkCreateSwapchainKHR: vk.PfnCreateSwapchainKHR,
    vkDestroyBuffer: vk.PfnDestroyBuffer,
    vkDestroyCommandPool: vk.PfnDestroyCommandPool,
    vkDestroyDescriptorPool: vk.PfnDestroyDescriptorPool,
    vkDestroyDescriptorSetLayout: vk.PfnDestroyDescriptorSetLayout,
    vkDestroyDevice: vk.PfnDestroyDevice,
    vkDestroyFence: vk.PfnDestroyFence,
    vkDestroyFramebuffer: vk.PfnDestroyFramebuffer,
    vkDestroyImage: vk.PfnDestroyImage,
    vkDestroyImageView: vk.PfnDestroyImageView,
    vkDestroyPipeline: vk.PfnDestroyPipeline,
    vkDestroyPipelineCache: vk.PfnDestroyPipelineCache,
    vkDestroyPipelineLayout: vk.PfnDestroyPipelineLayout,
    vkDestroyRenderPass: vk.PfnDestroyRenderPass,
    vkDestroySampler: vk.PfnDestroySampler,
    vkDestroySemaphore: vk.PfnDestroySemaphore,
    vkDestroyShaderModule: vk.PfnDestroyShaderModule,
    vkDestroySwapchainKHR: vk.PfnDestroySwapchainKHR,
    vkDeviceWaitIdle: vk.PfnDeviceWaitIdle,
    vkEndCommandBuffer: vk.PfnEndCommandBuffer,
    vkFlushMappedMemoryRanges: vk.PfnFlushMappedMemoryRanges,
    vkFreeCommandBuffers: vk.PfnFreeCommandBuffers,
    vkFreeMemory: vk.PfnFreeMemory,
    vkGetBufferMemoryRequirements: vk.PfnGetBufferMemoryRequirements,
    vkGetDeviceQueue: vk.PfnGetDeviceQueue,
    vkGetFenceStatus: vk.PfnGetFenceStatus,
    vkGetImageMemoryRequirements: vk.PfnGetImageMemoryRequirements,
    vkGetSwapchainImagesKHR: vk.PfnGetSwapchainImagesKHR,
    vkMapMemory: vk.PfnMapMemory,
    vkQueuePresentKHR: vk.PfnQueuePresentKHR,
    vkQueueSubmit: vk.PfnQueueSubmit,
    vkQueueWaitIdle: vk.PfnQueueWaitIdle,
    vkResetCommandBuffer: vk.PfnResetCommandBuffer,
    vkResetFences: vk.PfnResetFences,
    vkUnmapMemory: vk.PfnUnmapMemory,
    vkUpdateDescriptorSets: vk.PfnUpdateDescriptorSets,
    vkWaitForFences: vk.PfnWaitForFences,

    usingnamespace vk.DeviceWrapper(@This());
};
pub var vkd: DeviceDispatch = undefined;

pub var allocator: Allocator = undefined;
pub var instance: vk.Instance = undefined;
pub var physical_device: PhysicalDevice = undefined;

pub var surface: vk.SurfaceKHR = undefined;
pub var debug_messenger: vk.DebugUtilsMessengerEXT = undefined;
pub var device: vk.Device = undefined;

pub var graphics_queue: vk.Queue = undefined;
pub var present_queue: vk.Queue = undefined;
pub var compute_queue: vk.Queue = undefined;

pub fn init(a: Allocator, app: *Application) !void {
    // Workaround bug in amd driver, that reports zero vulkan capable gpu devices
    //https://github.com/KhronosGroup/Vulkan-Loader/issues/552
    if (builtin.target.os.tag == .windows) {
        _ = c._putenv("DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1");
        _ = c._putenv("DISABLE_LAYER_NV_OPTIMUS_1=1");
    }

    allocator = a;

    vkfn.b = try vkfn.FncBase.load(glfwGetInstanceProcAddress);

    instance = Instance.create(app.name, nyancore_options.use_vulkan_sdk, allocator) catch |err| {
        printVulkanError("Error during instance creation", err);
        return err;
    };
    errdefer vkfn.i.destroyInstance(instance, null);
    vkfn.i = try vkfn.InstanceDispatch.load(instance, glfwGetInstanceProcAddress);

    createSurface(app.window) catch |err| {
        printVulkanError("Error during surface creation", err);
        return err;
    };
    errdefer vkfn.i.destroySurfaceKHR(instance, surface, null);

    if (nyancore_options.use_vulkan_sdk) {
        setupDebugMessenger() catch |err| {
            printVulkanError("Error setting up debug messenger", err);
            return err;
        };
        errdefer vkfn.i.destroyDebugUtilsMessengerEXT(instance, debug_messenger, null);
    }

    physical_device = PhysicalDevice.pick() catch |err| {
        printVulkanError("Error picking physical device", err);
        return err;
    };

    createLogicalDevice() catch |err| {
        printVulkanError("Error creating logical device", err);
        return err;
    };

    vkd = try DeviceDispatch.load(device, vkfn.i.vkGetDeviceProcAddr);
    errdefer vkd.destroyDevice(device, null);

    graphics_queue = vkd.getDeviceQueue(device, physical_device.family_indices.graphics_family, 0);
    present_queue = vkd.getDeviceQueue(device, physical_device.family_indices.present_family, 0);
    compute_queue = vkd.getDeviceQueue(device, physical_device.family_indices.compute_family, 0);
}

pub fn deinit() void {
    vkd.destroyDevice(device, null);

    if (nyancore_options.use_vulkan_sdk) {
        vkfn.i.destroyDebugUtilsMessengerEXT(instance, debug_messenger, null);
    }

    vkfn.i.destroySurfaceKHR(instance, surface, null);
    Instance.destroy(instance);
}

pub fn getMemoryType(type_bits: u32, properties: vk.MemoryPropertyFlags) u32 {
    var temp: u32 = type_bits;
    for (physical_device.memory_properties.memory_types) |mem_type, ind| {
        if ((temp & 1) == 1)
            if ((mem_type.property_flags.toInt() & properties.toInt()) == properties.toInt())
                return @intCast(u32, ind);
        temp >>= 1;
    }
    @panic("Can't get memory type");
}

fn createSurface(window: *c.GLFWwindow) !void {
    const res: vk.Result = glfwCreateWindowSurface(instance, window, null, &surface);
    if (res != .success) {
        printError("Vulkan", "Glfw couldn't create window surface for vulkan context");
        return error.Unknown;
    }
}

fn vulkanDebugCallback(
    message_severity: vk.DebugUtilsMessageSeverityFlagsEXT.IntType,
    message_types: vk.DebugUtilsMessageTypeFlagsEXT.IntType,
    p_callback_data: *const vk.DebugUtilsMessengerCallbackDataEXT,
    p_user_data: *anyopaque,
) callconv(vk.vulkan_call_conv) vk.Bool32 {
    _ = message_severity;
    _ = message_types;
    _ = p_user_data;
    printErrorNoPanic("Vulkan Validation Layer", std.mem.span(p_callback_data.p_message));
    return 1;
}

fn setupDebugMessenger() !void {
    const create_info: vk.DebugUtilsMessengerCreateInfoEXT = .{
        .flags = .{},
        .message_severity = .{
            .warning_bit_ext = true,
            .error_bit_ext = true,
        },
        .message_type = .{
            .general_bit_ext = true,
            .validation_bit_ext = true,
            .performance_bit_ext = true,
        },
        .pfn_user_callback = vulkanDebugCallback,
        .p_user_data = null,
    };

    debug_messenger = vkfn.i.createDebugUtilsMessengerEXT(instance, create_info, null) catch |err| {
        printVulkanError("Can't create debug messenger", err);
        return err;
    };
}

fn createLogicalDevice() !void {
    var queue_indices: [3]u32 = [_]u32{
        physical_device.family_indices.present_family,
        physical_device.family_indices.graphics_family,
        physical_device.family_indices.compute_family,
    };

    std.sort.sort(u32, queue_indices[0..], {}, comptime std.sort.asc(u32));

    var queue_create_info: [3]vk.DeviceQueueCreateInfo = [_]vk.DeviceQueueCreateInfo{ undefined, undefined, undefined };
    var queue_create_info_count: usize = 0;
    var i: usize = 0;
    var last_family: u32 = undefined;
    const queue_priority: f32 = 1.0;
    while (i < std.mem.len(queue_indices)) : (i += 1) {
        if (queue_indices[i] != last_family) {
            queue_create_info[queue_create_info_count] = .{
                .flags = .{},
                .queue_family_index = queue_indices[i],
                .queue_count = 1,
                .p_queue_priorities = @ptrCast([*]const f32, &queue_priority),
            };
            last_family = queue_indices[i];
            queue_create_info_count += 1;
        }
    }

    const create_info: vk.DeviceCreateInfo = .{
        .flags = .{},
        .p_queue_create_infos = @ptrCast([*]const vk.DeviceQueueCreateInfo, &queue_create_info),
        .queue_create_info_count = @intCast(u32, queue_create_info_count),
        .p_enabled_features = null,
        .enabled_layer_count = if (nyancore_options.use_vulkan_sdk) @intCast(u32, std.mem.len(validation_layers)) else 0,
        .pp_enabled_layer_names = if (nyancore_options.use_vulkan_sdk) @ptrCast([*]const [*:0]const u8, &validation_layers) else undefined,
        .enabled_extension_count = @intCast(u32, std.mem.len(required_device_extensions)),
        .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, &required_device_extensions),
    };

    device = vkfn.i.createDevice(physical_device.vk_reference, create_info, null) catch |err| {
        printVulkanError("Can't create device", err);
        return err;
    };
}
