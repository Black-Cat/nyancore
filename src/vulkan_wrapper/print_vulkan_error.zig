const std = @import("std");
const vk = @import("../vk.zig");

const app_namespace = @import("../application/application.zig");

const Allocator = std.mem.allocator;

const printError = @import("../application/print_error.zig").printError;

const VulkanError = error{
    DeviceLost,
    ExtensionNotPresent,
    FeatureNotPresent,
    FragmentationEXT,
    FragmentedPool,
    HostAllocationError,
    IncompatibleDriver,
    InitializationFailed,
    InvalidExternalHandle,
    InvalidOpaqueCaptureAddressKHR,
    InvalidShaderNV,
    LayerNotPresent,
    MemoryMapFailed,
    NativeWindowInUseKHR,
    OutOfDeviceMemory,
    OutOfHostMemory,
    OutOfPoolMemory,
    SurfaceLostKHR,
    TooManyObjects,
    Unknown,
    ValidationLayerNotSupported,
};

pub fn printVulkanError(comptime err_context: []const u8, err: VulkanError) void {
    @setCold(true);

    const vulkan_error_message: []const u8 = switch (err) {
        error.DeviceLost => "Device lost",
        error.ExtensionNotPresent => "Extension not present",
        error.FeatureNotPresent => "Feature not present",
        error.FragmentationEXT => "Fragmentation",
        error.FragmentedPool => "Fragmented pool",
        error.HostAllocationError => "Error during allocation on host",
        error.IncompatibleDriver => "Incompatible driver",
        error.InitializationFailed => "Initialization failed",
        error.InvalidExternalHandle => "Invalid external handle",
        error.InvalidOpaqueCaptureAddressKHR => "Invalid opaque capture address KHR",
        error.InvalidShaderNV => "Invalid Shader",
        error.MemoryMapFailed => "Memory map failed",
        error.NativeWindowInUseKHR => "Native window in use",
        error.LayerNotPresent => "Layer not present",
        error.OutOfDeviceMemory => "Out of device memory",
        error.OutOfHostMemory => "Out of host memory",
        error.OutOfPoolMemory => "Out of pool memory",
        error.SurfaceLostKHR => "Surface lost",
        error.TooManyObjects => "Too many objects",
        error.Unknown => "Unknown error",
        error.ValidationLayerNotSupported => "Validation layer not supported",
    };

    const message: []const u8 = std.mem.join(app_namespace.app.allocator, ": ", &[_][]const u8{ err_context, vulkan_error_message }) catch unreachable;
    defer app_namespace.app.allocator.free(message);

    printError("Vulkan", message);
}
