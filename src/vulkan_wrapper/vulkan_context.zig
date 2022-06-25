const nyancore_options = @import("nyancore_options");
const c = @import("../c.zig");
const std = @import("std");
const vk = @import("../vk.zig");
const builtin = @import("builtin");
const vkfn = @import("vulkan_functions.zig");

const Allocator = std.mem.Allocator;
const Application = @import("../application/application.zig").Application;
const Instance = @import("instance.zig");

const printError = @import("../application/print_error.zig").printError;
const printErrorNoPanic = @import("../application/print_error.zig").printErrorNoPanic;
const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
pub extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *c.GLFWwindow, alocation_callback: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;

const required_device_extensions: [1][:0]const u8 = [_][:0]const u8{
    "VK_KHR_swapchain",
};

const validation_layers: [1][:0]const u8 = [_][:0]const u8{
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

        self.buffer = vkd.createBuffer(vkc.device, buffer_info, null) catch |err| {
            printVulkanError("Can't create buffer for ui", err);
            return;
        };

        var mem_req: vk.MemoryRequirements = vkd.getBufferMemoryRequirements(vkc.device, self.buffer);

        const alloc_info: vk.MemoryAllocateInfo = .{
            .allocation_size = mem_req.size,
            .memory_type_index = vkc.getMemoryType(mem_req.memory_type_bits, properties),
        };

        self.memory = vkd.allocateMemory(vkc.device, alloc_info, null) catch |err| {
            printVulkanError("Can't allocate buffer for ui", err);
            return;
        };

        vkd.bindBufferMemory(vkc.device, self.buffer, self.memory, 0) catch |err| {
            printVulkanError("Can't bind buffer memory for ui", err);
            return;
        };

        self.mapped_memory = vkd.mapMemory(vkc.device, self.memory, 0, size, .{}) catch |err| {
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

        vkd.flushMappedMemoryRanges(vkc.device, 1, @ptrCast([*]const vk.MappedMemoryRange, &mapped_range)) catch |err| {
            printVulkanError("Can't flush buffer for ui", err);
        };
    }

    pub fn destroy(self: *Buffer) void {
        vkd.unmapMemory(vkc.device, self.memory);
        vkd.destroyBuffer(vkc.device, self.buffer, null);
        vkd.freeMemory(vkc.device, self.memory, null);
    }
};

const InstanceDispatch = if (nyancore_options.use_vulkan_sdk) struct {
    vkCreateDebugUtilsMessengerEXT: vk.PfnCreateDebugUtilsMessengerEXT,
    vkDestroyDebugUtilsMessengerEXT: vk.PfnDestroyDebugUtilsMessengerEXT,

    vkCreateDevice: vk.PfnCreateDevice,
    vkDestroyInstance: vk.PfnDestroyInstance,
    vkDestroySurfaceKHR: vk.PfnDestroySurfaceKHR,
    vkEnumerateDeviceExtensionProperties: vk.PfnEnumerateDeviceExtensionProperties,
    vkEnumeratePhysicalDevices: vk.PfnEnumeratePhysicalDevices,
    vkGetDeviceProcAddr: vk.PfnGetDeviceProcAddr,
    vkGetPhysicalDeviceMemoryProperties: vk.PfnGetPhysicalDeviceMemoryProperties,
    vkGetPhysicalDeviceQueueFamilyProperties: vk.PfnGetPhysicalDeviceQueueFamilyProperties,
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR: vk.PfnGetPhysicalDeviceSurfaceCapabilitiesKHR,
    vkGetPhysicalDeviceSurfaceFormatsKHR: vk.PfnGetPhysicalDeviceSurfaceFormatsKHR,
    vkGetPhysicalDeviceSurfacePresentModesKHR: vk.PfnGetPhysicalDeviceSurfacePresentModesKHR,
    vkGetPhysicalDeviceSurfaceSupportKHR: vk.PfnGetPhysicalDeviceSurfaceSupportKHR,
    usingnamespace vk.InstanceWrapper(@This());
} else struct {
    vkCreateDevice: vk.PfnCreateDevice,
    vkDestroyInstance: vk.PfnDestroyInstance,
    vkDestroySurfaceKHR: vk.PfnDestroySurfaceKHR,
    vkEnumerateDeviceExtensionProperties: vk.PfnEnumerateDeviceExtensionProperties,
    vkEnumeratePhysicalDevices: vk.PfnEnumeratePhysicalDevices,
    vkGetDeviceProcAddr: vk.PfnGetDeviceProcAddr,
    vkGetPhysicalDeviceMemoryProperties: vk.PfnGetPhysicalDeviceMemoryProperties,
    vkGetPhysicalDeviceQueueFamilyProperties: vk.PfnGetPhysicalDeviceQueueFamilyProperties,
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR: vk.PfnGetPhysicalDeviceSurfaceCapabilitiesKHR,
    vkGetPhysicalDeviceSurfaceFormatsKHR: vk.PfnGetPhysicalDeviceSurfaceFormatsKHR,
    vkGetPhysicalDeviceSurfacePresentModesKHR: vk.PfnGetPhysicalDeviceSurfacePresentModesKHR,
    vkGetPhysicalDeviceSurfaceSupportKHR: vk.PfnGetPhysicalDeviceSurfaceSupportKHR,
    usingnamespace vk.InstanceWrapper(@This());
};

pub var vki: InstanceDispatch = undefined;

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

pub const SwapchainSupportDetails = struct {
    capabilities: vk.SurfaceCapabilitiesKHR,
    formats: []vk.SurfaceFormatKHR,
    format_count: u32,
    present_modes: []vk.PresentModeKHR,
    present_mode_count: u32,
};

const QueueFamilyIndices = struct {
    graphics_family: u32,
    present_family: u32,
    compute_family: u32,

    graphics_family_set: bool,
    present_family_set: bool,
    compute_family_set: bool,

    pub fn isComplete(self: *const QueueFamilyIndices) bool {
        return self.graphics_family_set and self.present_family_set and self.compute_family_set;
    }
};

pub var vkc: VulkanContext = undefined;

pub const VulkanContext = struct {
    allocator: Allocator,

    instance: vk.Instance,
    surface: vk.SurfaceKHR,
    debug_messenger: vk.DebugUtilsMessengerEXT,
    physical_device: vk.PhysicalDevice,
    memory_properties: vk.PhysicalDeviceMemoryProperties,
    family_indices: QueueFamilyIndices,
    device: vk.Device,

    graphics_queue: vk.Queue,
    present_queue: vk.Queue,
    compute_queue: vk.Queue,

    pub fn init(self: *VulkanContext, allocator: Allocator, app: *Application) !void {
        // Workaround bug in amd driver, that reports zero vulkan capable gpu devices
        //https://github.com/KhronosGroup/Vulkan-Loader/issues/552
        if (builtin.target.os.tag == .windows) {
            _ = c._putenv("DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1");
            _ = c._putenv("DISABLE_LAYER_NV_OPTIMUS_1=1");
        }

        self.allocator = allocator;

        vkfn.b = try vkfn.FncBase.load(glfwGetInstanceProcAddress);

        self.instance = Instance.create(app.name, nyancore_options.use_vulkan_sdk, self.allocator) catch |err| {
            printVulkanError("Error during instance creation", err);
            return err;
        };
        errdefer vki.destroyInstance(self.instance, null);
        vki = try InstanceDispatch.load(self.instance, glfwGetInstanceProcAddress);

        self.createSurface(app.window) catch |err| {
            printVulkanError("Error during surface creation", err);
            return err;
        };
        errdefer vki.destroySurfaceKHR(self.instance, self.surface, null);

        if (nyancore_options.use_vulkan_sdk) {
            self.setupDebugMessenger() catch |err| {
                printVulkanError("Error setting up debug messenger", err, self.allocator);
                return err;
            };
            errdefer vki.destroyDebugUtilsMessengerEXT(self.instance, self.debug_messenger, null);
        }

        self.pickPhysicalDevice() catch |err| {
            printVulkanError("Error picking physical device", err);
            return err;
        };
        self.createLogicalDevice() catch |err| {
            printVulkanError("Error creating logical device", err);
            return err;
        };

        vkd = try DeviceDispatch.load(self.device, vki.vkGetDeviceProcAddr);
        errdefer vkd.destroyDevice(self.device, null);

        self.graphics_queue = vkd.getDeviceQueue(self.device, self.family_indices.graphics_family, 0);
        self.present_queue = vkd.getDeviceQueue(self.device, self.family_indices.present_family, 0);
        self.compute_queue = vkd.getDeviceQueue(self.device, self.family_indices.compute_family, 0);
    }

    pub fn deinit(self: *VulkanContext) void {
        vkd.destroyDevice(self.device, null);

        if (nyancore_options.use_vulkan_sdk) {
            vki.destroyDebugUtilsMessengerEXT(self.instance, self.debug_messenger, null);
        }

        vki.destroySurfaceKHR(self.instance, self.surface, null);
        vki.destroyInstance(self.instance, null);
    }

    pub fn getMemoryType(self: *VulkanContext, type_bits: u32, properties: vk.MemoryPropertyFlags) u32 {
        var temp: u32 = type_bits;
        for (self.memory_properties.memory_types) |mem_type, ind| {
            if ((temp & 1) == 1)
                if ((mem_type.property_flags.toInt() & properties.toInt()) == properties.toInt())
                    return @intCast(u32, ind);
            temp >>= 1;
        }
        @panic("Can't get memory type");
    }

    fn createSurface(self: *VulkanContext, window: *c.GLFWwindow) !void {
        const res: vk.Result = glfwCreateWindowSurface(self.instance, window, null, &self.surface);
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

    fn setupDebugMessenger(self: *VulkanContext) !void {
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

        self.debug_messenger = vki.createDebugUtilsMessengerEXT(self.instance, create_info, null) catch |err| {
            printVulkanError("Can't create debug messenger", err, self.allocator);
            return err;
        };
    }

    fn checkDeviceExtensionsSupport(self: *VulkanContext, device: *const vk.PhysicalDevice) !bool {
        var extension_count: u32 = undefined;
        _ = vki.enumerateDeviceExtensionProperties(device.*, null, &extension_count, null) catch |err| {
            printVulkanError("Can't get count of device extensions", err);
            return err;
        };

        var available_extensions: []vk.ExtensionProperties = self.allocator.alloc(vk.ExtensionProperties, extension_count) catch {
            printError("Vulkan", "Can't allocate information for available extensions");
            return error.HostAllocationError;
        };
        defer self.allocator.free(available_extensions);
        _ = vki.enumerateDeviceExtensionProperties(device.*, null, &extension_count, @ptrCast([*]vk.ExtensionProperties, available_extensions)) catch |err| {
            printVulkanError("Can't get information about available extensions", err);
            return err;
        };

        for (required_device_extensions) |req_ext| {
            var extension_found: bool = false;
            for (available_extensions) |ext| {
                if (std.mem.startsWith(u8, ext.extension_name[0..], req_ext)) {
                    extension_found = true;
                    break;
                }
            }
            if (!extension_found) {
                return false;
            }
        }

        return true;
    }

    pub fn getSwapchainSupport(self: *const VulkanContext, device: *const vk.PhysicalDevice) !SwapchainSupportDetails {
        var details: SwapchainSupportDetails = undefined;

        details.capabilities = vki.getPhysicalDeviceSurfaceCapabilitiesKHR(device.*, self.surface) catch |err| {
            printVulkanError("Can't get physical device surface capabilities", err);
            return err;
        };

        _ = vki.getPhysicalDeviceSurfaceFormatsKHR(device.*, self.surface, &details.format_count, null) catch |err| {
            printVulkanError("Can't get physical device's formats count", err);
            return err;
        };
        if (details.format_count > 0) {
            details.formats = self.allocator.alloc(vk.SurfaceFormatKHR, details.format_count) catch {
                printError("Vulkan", "Can't allocate memory for device formats");
                return error.HostAllocationError;
            };
            _ = vki.getPhysicalDeviceSurfaceFormatsKHR(device.*, self.surface, &details.format_count, @ptrCast([*]vk.SurfaceFormatKHR, details.formats)) catch |err| {
                printVulkanError("Can't get information about physical device's supported formats", err);
                return err;
            };
        }

        _ = vki.getPhysicalDeviceSurfacePresentModesKHR(device.*, self.surface, &details.present_mode_count, null) catch |err| {
            printVulkanError("Can't get physical device's present modes count", err);
            return err;
        };
        if (details.present_mode_count > 0) {
            details.present_modes = self.allocator.alloc(vk.PresentModeKHR, details.present_mode_count) catch {
                printError("Vulkan", "Can't allocate memory for device present modes");
                return error.HostAllocationError;
            };
            _ = vki.getPhysicalDeviceSurfacePresentModesKHR(device.*, self.surface, &details.present_mode_count, @ptrCast([*]vk.PresentModeKHR, details.present_modes)) catch |err| {
                printVulkanError("Can't get information about physical device present modes", err);
                return err;
            };
        }

        return details;
    }

    fn findQueueFamilyIndices(self: *VulkanContext, device: *const vk.PhysicalDevice) !QueueFamilyIndices {
        var indices: QueueFamilyIndices = undefined;

        var queue_family_count: u32 = undefined;
        vki.getPhysicalDeviceQueueFamilyProperties(device.*, &queue_family_count, null);

        var queue_families: []vk.QueueFamilyProperties = self.allocator.alloc(vk.QueueFamilyProperties, queue_family_count) catch {
            printError("Vulkan", "Can't allocate information for queue families");
            return error.HostAllocationError;
        };
        defer self.allocator.free(queue_families);
        vki.getPhysicalDeviceQueueFamilyProperties(device.*, &queue_family_count, @ptrCast([*]vk.QueueFamilyProperties, queue_families));

        for (queue_families) |family, i| {
            if (family.queue_flags.graphics_bit) {
                indices.graphics_family = @intCast(u32, i);
                indices.graphics_family_set = true;
            }

            if (family.queue_flags.compute_bit) {
                indices.compute_family = @intCast(u32, i);
                indices.compute_family_set = true;
            }

            var present_support: vk.Bool32 = vki.getPhysicalDeviceSurfaceSupportKHR(device.*, @intCast(u32, i), self.surface) catch |err| {
                printVulkanError("Can't get physical device surface support information", err);
                return err;
            };
            if (present_support != 0) {
                indices.present_family = @intCast(u32, i);
                indices.present_family_set = true;
            }

            if (indices.isComplete()) {
                break;
            }
        }

        return indices;
    }

    fn isDeviceSuitable(self: *VulkanContext, device: *const vk.PhysicalDevice) !bool {
        const extensions_supported: bool = self.checkDeviceExtensionsSupport(device) catch |err| {
            printVulkanError("Error while checking device extensions", err);
            return err;
        };

        if (!extensions_supported) {
            return false;
        }

        var swapchain_support: SwapchainSupportDetails = self.getSwapchainSupport(device) catch |err| {
            printVulkanError("Can't get swapchain support details", err);
            return err;
        };
        defer self.allocator.free(swapchain_support.formats);
        defer self.allocator.free(swapchain_support.present_modes);

        if (swapchain_support.format_count < 1 or swapchain_support.present_mode_count < 1) {
            return false;
        }

        const indices: QueueFamilyIndices = self.findQueueFamilyIndices(device) catch |err| {
            printVulkanError("Can't get family indices", err);
            return err;
        };
        if (!indices.isComplete()) {
            return false;
        }

        return true;
    }

    fn pickPhysicalDevice(self: *VulkanContext) !void {
        var gpu_count: u32 = undefined;
        _ = vki.enumeratePhysicalDevices(self.instance, &gpu_count, null) catch |err| {
            printVulkanError("Can't get physical device count", err);
            return err;
        };

        var physical_devices: []vk.PhysicalDevice = self.allocator.alloc(vk.PhysicalDevice, gpu_count) catch {
            printError("Vulkan", "Can't allocate information for physical devices");
            return error.HostAllocationError;
        };
        defer self.allocator.free(physical_devices);

        _ = vki.enumeratePhysicalDevices(self.instance, &gpu_count, @ptrCast([*]vk.PhysicalDevice, physical_devices)) catch |err| {
            printVulkanError("Can't get physical devices information", err);
            return err;
        };

        for (physical_devices) |device| {
            if (self.isDeviceSuitable(&device)) {
                self.physical_device = device;
                self.memory_properties = vki.getPhysicalDeviceMemoryProperties(self.physical_device);
                self.family_indices = self.findQueueFamilyIndices(&self.physical_device) catch unreachable;
                return;
            } else |err| {
                printVulkanError("Error checking physical device suitabilty", err);
                return err;
            }
        }

        printError("Vulkan", "Can't find suitable device");
        return error.Unknown;
    }

    fn createLogicalDevice(self: *VulkanContext) !void {
        var queue_indices: [3]u32 = [_]u32{
            self.family_indices.present_family,
            self.family_indices.graphics_family,
            self.family_indices.compute_family,
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

        self.device = vki.createDevice(self.physical_device, create_info, null) catch |err| {
            printVulkanError("Can't create device", err);
            return err;
        };
    }
};
