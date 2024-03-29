const std = @import("std");

const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printError = @import("../application/print_error.zig").printError;
const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub const QueueFamilyIndices = struct {
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

pub const PhysicalDevice = struct {
    pub const SwapchainSupportDetails = struct {
        capabilities: vk.SurfaceCapabilitiesKHR,
        formats: []vk.SurfaceFormatKHR,
        format_count: u32,
        present_modes: []vk.PresentModeKHR,
        present_mode_count: u32,
    };

    vk_ref: vk.PhysicalDevice,
    memory_properties: vk.PhysicalDeviceMemoryProperties,
    device_properties: vk.PhysicalDeviceProperties,
    family_indices: QueueFamilyIndices,

    pub fn pick() !PhysicalDevice {
        var gpu_count: u32 = undefined;
        _ = vkfn.i.enumeratePhysicalDevices(vkctxt.instance, &gpu_count, null) catch |err| {
            printVulkanError("Can't get physical device count", err);
            return err;
        };

        var physical_devices: []vk.PhysicalDevice = vkctxt.allocator.alloc(vk.PhysicalDevice, gpu_count) catch {
            printError("Vulkan", "Can't allocate information for physical devices");
            return error.HostAllocationError;
        };
        defer vkctxt.allocator.free(physical_devices);

        _ = vkfn.i.enumeratePhysicalDevices(vkctxt.instance, &gpu_count, @ptrCast(physical_devices)) catch |err| {
            printVulkanError("Can't get physical devices information", err);
            return err;
        };

        for (physical_devices) |device| {
            if (isDeviceSuitable(device)) |_| {
                const picked_device: PhysicalDevice = .{
                    .vk_ref = device,
                    .memory_properties = vkfn.i.getPhysicalDeviceMemoryProperties(device),
                    .device_properties = vkfn.i.getPhysicalDeviceProperties(device),
                    .family_indices = findQueueFamilyIndices(device) catch unreachable,
                };
                return picked_device;
            } else |err| {
                printVulkanError("Error checking physical device suitabilty", err);
                return err;
            }
        }

        printError("Vulkan", "Can't find suitable device");
        return error.Unknown;
    }

    fn isDeviceSuitable(device: vk.PhysicalDevice) !bool {
        const extensions_supported: bool = checkDeviceExtensionsSupport(device) catch |err| {
            printVulkanError("Error while checking device extensions", err);
            return err;
        };

        const features_supported: bool = checkDeviceFeatures(device);

        if (!extensions_supported or !features_supported) {
            return false;
        }

        var swapchain_support: SwapchainSupportDetails = getSwapchainSupport(device) catch |err| {
            printVulkanError("Can't get swapchain support details", err);
            return err;
        };
        defer vkctxt.allocator.free(swapchain_support.formats);
        defer vkctxt.allocator.free(swapchain_support.present_modes);

        if (swapchain_support.format_count < 1 or swapchain_support.present_mode_count < 1) {
            return false;
        }

        const indices: QueueFamilyIndices = findQueueFamilyIndices(device) catch |err| {
            printVulkanError("Can't get family indices", err);
            return err;
        };
        if (!indices.isComplete()) {
            return false;
        }

        return true;
    }

    fn findQueueFamilyIndices(device: vk.PhysicalDevice) !QueueFamilyIndices {
        var indices: QueueFamilyIndices = undefined;

        var queue_family_count: u32 = undefined;
        vkfn.i.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);

        var queue_families: []vk.QueueFamilyProperties = vkctxt.allocator.alloc(vk.QueueFamilyProperties, queue_family_count) catch {
            printError("Vulkan", "Can't allocate information for queue families");
            return error.HostAllocationError;
        };
        defer vkctxt.allocator.free(queue_families);
        vkfn.i.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, @ptrCast(queue_families));

        for (queue_families, 0..) |family, i| {
            if (family.queue_flags.graphics_bit) {
                indices.graphics_family = @intCast(i);
                indices.graphics_family_set = true;
            }

            if (family.queue_flags.compute_bit) {
                indices.compute_family = @intCast(i);
                indices.compute_family_set = true;
            }

            var present_support: vk.Bool32 = vkfn.i.getPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), vkctxt.surface) catch |err| {
                printVulkanError("Can't get physical device surface support information", err);
                return err;
            };
            if (present_support != 0) {
                indices.present_family = @intCast(i);
                indices.present_family_set = true;
            }

            if (indices.isComplete()) {
                break;
            }
        }

        return indices;
    }

    fn checkDeviceFeatures(device: vk.PhysicalDevice) bool {
        var features_11: vk.PhysicalDeviceVulkan11Features = .{};
        var features_12: vk.PhysicalDeviceVulkan12Features = .{ .p_next = &features_11 };
        var features_13: vk.PhysicalDeviceVulkan13Features = .{ .p_next = &features_12 };

        const features: vk.PhysicalDeviceFeatures = vkfn.i.getPhysicalDeviceFeatures(device);
        var features2: vk.PhysicalDeviceFeatures2 = .{
            .p_next = &features_13,
            .features = features,
        };
        vkfn.i.getPhysicalDeviceFeatures2(device, &features2);

        return features_11.shader_draw_parameters == vk.TRUE and
            features_12.buffer_device_address == vk.TRUE and
            features_12.descriptor_indexing == vk.TRUE and
            features_13.dynamic_rendering == vk.TRUE and
            features_13.synchronization_2 == vk.TRUE;
    }

    fn checkDeviceExtensionsSupport(device: vk.PhysicalDevice) !bool {
        var extension_count: u32 = undefined;
        _ = vkfn.i.enumerateDeviceExtensionProperties(device, null, &extension_count, null) catch |err| {
            printVulkanError("Can't get count of device extensions", err);
            return err;
        };

        var available_extensions: []vk.ExtensionProperties = vkctxt.allocator.alloc(vk.ExtensionProperties, extension_count) catch {
            printError("Vulkan", "Can't allocate information for available extensions");
            return error.HostAllocationError;
        };
        defer vkctxt.allocator.free(available_extensions);
        _ = vkfn.i.enumerateDeviceExtensionProperties(device, null, &extension_count, @ptrCast(available_extensions)) catch |err| {
            printVulkanError("Can't get information about available extensions", err);
            return err;
        };

        for (vkctxt.required_device_extensions) |req_ext| {
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

    pub fn getSwapchainSupport(device: vk.PhysicalDevice) !SwapchainSupportDetails {
        var details: SwapchainSupportDetails = undefined;

        details.capabilities = vkfn.i.getPhysicalDeviceSurfaceCapabilitiesKHR(device, vkctxt.surface) catch |err| {
            printVulkanError("Can't get physical device surface capabilities", err);
            return err;
        };

        _ = vkfn.i.getPhysicalDeviceSurfaceFormatsKHR(device, vkctxt.surface, &details.format_count, null) catch |err| {
            printVulkanError("Can't get physical device's formats count", err);
            return err;
        };
        if (details.format_count > 0) {
            details.formats = vkctxt.allocator.alloc(vk.SurfaceFormatKHR, details.format_count) catch {
                printError("Vulkan", "Can't allocate memory for device formats");
                return error.HostAllocationError;
            };
            _ = vkfn.i.getPhysicalDeviceSurfaceFormatsKHR(device, vkctxt.surface, &details.format_count, @ptrCast(details.formats)) catch |err| {
                printVulkanError("Can't get information about physical device's supported formats", err);
                return err;
            };
        }

        _ = vkfn.i.getPhysicalDeviceSurfacePresentModesKHR(device, vkctxt.surface, &details.present_mode_count, null) catch |err| {
            printVulkanError("Can't get physical device's present modes count", err);
            return err;
        };
        if (details.present_mode_count > 0) {
            details.present_modes = vkctxt.allocator.alloc(vk.PresentModeKHR, details.present_mode_count) catch {
                printError("Vulkan", "Can't allocate memory for device present modes");
                return error.HostAllocationError;
            };
            _ = vkfn.i.getPhysicalDeviceSurfacePresentModesKHR(device, vkctxt.surface, &details.present_mode_count, @ptrCast(details.present_modes)) catch |err| {
                printVulkanError("Can't get information about physical device present modes", err);
                return err;
            };
        }

        return details;
    }
};
