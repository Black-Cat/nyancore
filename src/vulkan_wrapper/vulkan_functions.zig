const vk = @import("../vk.zig");
const nyancore_options = @import("nyancore_options");

pub const FncBase = struct {
    vkCreateInstance: vk.PfnCreateInstance,
    vkEnumerateInstanceLayerProperties: vk.PfnEnumerateInstanceLayerProperties,
    usingnamespace vk.BaseWrapper(@This());
};

pub var b: FncBase = undefined;

pub const InstanceDispatch = if (nyancore_options.use_vulkan_sdk) struct {
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

pub var i: InstanceDispatch = undefined;
