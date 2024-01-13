const std = @import("std");
const vk = @import("../vk.zig");

const app_namespace = @import("../application/application.zig");

const Allocator = std.mem.allocator;

const printError = @import("../application/print_error.zig").printError;

const VulkanError = error{
    CompressionExhaustedEXT,
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
    InvalidVideoStdParametersKHR,
    FullScreenExclusiveModeLostEXT,
    LayerNotPresent,
    MemoryMapFailed,
    NativeWindowInUseKHR,
    OutOfDateKHR,
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
        error.CompressionExhaustedEXT => "Compression exhaused",
        error.DeviceLost => "Device lost",
        error.ExtensionNotPresent => "Extension not present",
        error.FeatureNotPresent => "Feature not present",
        error.FragmentationEXT => "Fragmentation",
        error.FragmentedPool => "Fragmented pool",
        error.HostAllocationError => "Error during allocation on host",
        error.IncompatibleDriver => "Incompatible driver",
        error.InitializationFailed => "Initialization failed",
        error.InvalidExternalHandle => "Invalid external handle",
        error.InvalidOpaqueCaptureAddressKHR => "Invalid opaque capture address",
        error.InvalidShaderNV => "Invalid Shader",
        error.InvalidVideoStdParametersKHR => "Invalid video std parameters",
        error.FullScreenExclusiveModeLostEXT => "Full screen exclusive mode lost",
        error.MemoryMapFailed => "Memory map failed",
        error.NativeWindowInUseKHR => "Native window in use",
        error.LayerNotPresent => "Layer not present",
        error.OutOfDateKHR => "Out of date",
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
