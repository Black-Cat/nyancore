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
const Device = @import("device.zig");

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

pub var allocator: Allocator = undefined;
pub var instance: vk.Instance = undefined;
pub var physical_device: PhysicalDevice = undefined;

pub var surface: vk.SurfaceKHR = undefined;
pub var debug_messenger: vk.DebugUtilsMessengerEXT = undefined;
pub var device: vk.Device = undefined;

pub var graphics_queue: vk.Queue = undefined;
pub var present_queue: vk.Queue = undefined;
pub var compute_queue: vk.Queue = undefined;

pub var vma_allocator: c.VmaAllocator = undefined;

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

    device = Device.create(&physical_device) catch |err| {
        printVulkanError("Error creating logical device", err);
        return err;
    };

    vkfn.d = try vkfn.DeviceDispatch.load(device, vkfn.i.vkGetDeviceProcAddr);
    errdefer vkfn.d.destroyDevice(device, null);

    graphics_queue = vkfn.d.getDeviceQueue(device, physical_device.family_indices.graphics_family, 0);
    present_queue = vkfn.d.getDeviceQueue(device, physical_device.family_indices.present_family, 0);
    compute_queue = vkfn.d.getDeviceQueue(device, physical_device.family_indices.compute_family, 0);

    var vma_functions: c.VmaVulkanFunctions = std.mem.zeroes(c.VmaVulkanFunctions);
    vma_functions.vkGetInstanceProcAddr = @ptrCast(*const fn (?*c.VkInstance_T, [*c]const u8) callconv(.C) ?fn () callconv(.C) void, &glfwGetInstanceProcAddress).*;
    vma_functions.vkGetDeviceProcAddr = @ptrCast(*fn (?*c.VkDevice_T, [*c]const u8) callconv(.C) ?fn () callconv(.C) void, &vkfn.i.vkGetDeviceProcAddr).*;

    const vma_allocator_info: c.VmaAllocatorCreateInfo = .{
        // Bug in generated zig binding, all types are pointers =-=
        .physicalDevice = @intToPtr(*c.VkPhysicalDevice_T, @bitCast(usize, physical_device.vk_ref)),
        .device = @intToPtr(*c.VkDevice_T, @bitCast(usize, device)),
        .instance = @intToPtr(*c.VkInstance_T, @bitCast(usize, instance)),
        .pVulkanFunctions = &vma_functions,

        .flags = 0,
        .preferredLargeHeapBlockSize = 0,
        .pAllocationCallbacks = null,
        .pDeviceMemoryCallbacks = null,
        .pHeapSizeLimit = null,
        .vulkanApiVersion = 0,
        .pTypeExternalMemoryHandleTypes = null,
    };
    _ = c.vmaCreateAllocator(&vma_allocator_info, &vma_allocator);
}

pub fn deinit() void {
    c.vmaDestroyAllocator(vma_allocator.?);

    Device.destroy(device);

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
