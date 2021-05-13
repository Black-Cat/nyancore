const build_config = @import("../build_config.zig");
const c = @import("../c.zig");
const std = @import("std");
const vk = @import("vulkan");

const Allocator = std.mem.Allocator;
const printError = @import("../application/print_error.zig").printError;

const BaseDispatch = struct {
    vkEnumerateInstanceLayerProperties: vk.PfnEnumerateInstanceLayerProperties,
    usingnamespace vk.BaseWrapper(@This());
};

const InstanceDispatch = struct {
    usingnamespace vk.InstanceWrapper(@This());
};

const DeviceDispatch = struct {
    usingnamespace vk.DeviceWrapper(@This());
};

const VulkanError = error{
    HostAllocationError,
    OutOfDeviceMemory,
    OutOfHostMemory,
    Unknown,
    ValidationLayerNotSupported,
};

pub fn printVulkanError(comptime err_context: []const u8, err: VulkanError, allocator: *Allocator) void {
    @setCold(true);

    const vulkan_error_message: []const u8 = switch (err) {
        error.HostAllocationError => "Error during allocation on host",
        error.OutOfHostMemory => "Out of Host Memory",
        error.OutOfDeviceMemory => "Out of Device Memory",
        error.Unknown => "Unknown error",
        error.ValidationLayerNotSupported => "Validation layer not supported",
    };

    const message: []const u8 = std.mem.join(allocator, ": ", &[_][]const u8{ err_context, vulkan_error_message }) catch "=c Error while creating error message: " ++ err_context;
    defer allocator.free(message);
    printError("Vulkan", message);
}

pub const VulkanContext = struct {
    vkb: BaseDispatch,
    vki: InstanceDispatch,
    vkd: DeviceDispatch,

    allocator: *Allocator,

    instance: vk.Instance,

    pub fn init(self: *VulkanContext, allocator: *Allocator) !void {
        self.allocator = allocator;

        self.vkb = try BaseDispatch.load(c.glfwGetInstanceProcAddress);

        self.createInstance() catch |err| printVulkanError("Error during instance creation", err, self.allocator);
    }

    fn createInstance(self: *VulkanContext) !void {
        if (build_config.use_vulkan_sdk) {
            const validation_layers_supported: bool = self.checkValidationLayerSupport() catch |err| {
                printVulkanError("Error getting information about layers", err, self.allocator);
                return err;
            };
            if (!validation_layers_supported) {
                printError("Vulkan", "Validation layer not supported");
                return error.ValidationLayerNotSupported;
            }
        }
    }

    fn checkValidationLayerSupport(self: *VulkanContext) !bool {
        var layerCount: u32 = undefined;

        _ = self.vkb.enumerateInstanceLayerProperties(&layerCount, null) catch |err| {
            printVulkanError("Can't enumerate instance layer properties for layer support", err, self.allocator);
            return err;
        };

        var availableLayers: []vk.LayerProperties = self.allocator.alloc(vk.LayerProperties, layerCount) catch {
            printError("Vulkan", "Can't allocate memory for available layers");
            return error.HostAllocationError;
        };
        defer self.allocator.free(availableLayers);

        _ = self.vkb.enumerateInstanceLayerProperties(&layerCount, @ptrCast([*]vk.LayerProperties, availableLayers)) catch |err| {
            printVulkanError("Can't enumerate instance layer properties for layer support", err, self.allocator);
            return err;
        };

        return false;
    }
};
