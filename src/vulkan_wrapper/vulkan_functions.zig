const vk = @import("../vk.zig");
const nyancore_options = @import("nyancore_options");

pub const FncBase = struct {
    vkCreateInstance: vk.PfnCreateInstance,
    vkEnumerateInstanceLayerProperties: vk.PfnEnumerateInstanceLayerProperties,
    vkGetInstanceProcAddr: vk.PfnGetInstanceProcAddr,
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

pub const DeviceDispatch = struct {
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
pub var d: DeviceDispatch = undefined;
