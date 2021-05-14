const build_config = @import("../build_config.zig");
const c = @import("../c.zig");
const std = @import("std");
const vk = @import("vulkan");

const Allocator = std.mem.Allocator;
const Application = @import("../application/application.zig").Application;
const printError = @import("../application/print_error.zig").printError;

const required_device_extensions: [][:0]const u8 = [_][:0]const u8{
    "VK_KHR_swapchain",
};

const BaseDispatch = struct {
    vkCreateInstance: vk.PfnCreateInstance,
    vkEnumerateInstanceLayerProperties: vk.PfnEnumerateInstanceLayerProperties,
    usingnamespace vk.BaseWrapper(@This());
};

const InstanceDispatch = struct {
    vkCreateDebugUtilsMessengerEXT: vk.PfnCreateDebugUtilsMessengerEXT,
    usingnamespace vk.InstanceWrapper(@This());
};

const DeviceDispatch = struct {
    usingnamespace vk.DeviceWrapper(@This());
};

const VulkanError = error{
    ExtensionNotPresent,
    HostAllocationError,
    IncompatibleDriver,
    InitializationFailed,
    LayerNotPresent,
    OutOfDeviceMemory,
    OutOfHostMemory,
    Unknown,
    ValidationLayerNotSupported,
};

pub fn printVulkanError(comptime err_context: []const u8, err: VulkanError, allocator: *Allocator) void {
    @setCold(true);

    const vulkan_error_message: []const u8 = switch (err) {
        error.ExtensionNotPresent => "Extension not present",
        error.HostAllocationError => "Error during allocation on host",
        error.IncompatibleDriver => "Incompatible driver",
        error.InitializationFailed => "Initialization failed",
        error.LayerNotPresent => "Layer not present",
        error.OutOfDeviceMemory => "Out of device memory",
        error.OutOfHostMemory => "Out of host memory",
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
    surface: vk.SurfaceKHR,
    debug_messenger: vk.DebugUtilsMessengerEXT,
    physical_device: vk.PhysicalDevice,

    pub fn init(self: *VulkanContext, allocator: *Allocator, app: *Application) !void {
        self.allocator = allocator;

        self.vkb = try BaseDispatch.load(c.glfwGetInstanceProcAddress);

        self.createInstance(app.name) catch |err| printVulkanError("Error during instance creation", err, self.allocator);
        self.vki = try InstanceDispatch.load(self.instance, c.glfwGetInstanceProcAddress);

        self.createSurface(app.window) catch |err| printVulkanError("Error during surface creation", err, self.allocator);

        if (build_config.use_vulkan_sdk) {
            self.setupDebugMessenger() catch |err| printVulkanError("Error setting up debug messenger", err, self.allocator);
        }

        //self.pickPhysicalDevice() catch |err| printVulkanError("Error picking physical device", err, self.allocator);
    }

    fn createInstance(self: *VulkanContext, app_name: [:0]const u8) !void {
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

        const app_info: vk.ApplicationInfo = .{
            .p_application_name = app_name,
            .application_version = vk.makeApiVersion(0, 1, 0, 0),
            .p_engine_name = "nyancore engine",
            .engine_version = vk.makeApiVersion(0, 1, 0, 0),
            .api_version = vk.API_VERSION_1_2,
        };

        var glfw_extension_count: u32 = undefined;
        const glfw_extensions: [*c][*c]const u8 = c.glfwGetRequiredInstanceExtensions(&glfw_extension_count);

        const extensions_count: u32 = glfw_extension_count + 1 * @boolToInt(build_config.use_vulkan_sdk);
        var extensions: [][*c]const u8 = self.allocator.alloc([*c]const u8, extensions_count) catch {
            printError("Vulkan", "Can't allocate memory for extensions");
            return error.HostAllocationError;
        };
        defer self.allocator.free(extensions);

        var i: usize = 0;
        while (i < glfw_extension_count) : (i += 1) {
            extensions[i] = glfw_extensions[i];
        }

        const validation_layer: [*:0]const u8 = "VK_LAYER_KHRONOS_validation";
        if (build_config.use_vulkan_sdk) {
            extensions[i] = "VK_EXT_debug_utils";
        }

        const create_info: vk.InstanceCreateInfo = .{
            .p_application_info = &app_info,
            .enabled_extension_count = extensions_count,
            .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, extensions),
            .enabled_layer_count = if (build_config.use_vulkan_sdk) 1 else 0,
            .pp_enabled_layer_names = if (build_config.use_vulkan_sdk) @ptrCast([*]const [*:0]const u8, &validation_layer) else null,
            .flags = .{},
        };

        self.instance = self.vkb.createInstance(create_info, null) catch |err| {
            printVulkanError("Couldn't create vulkan instance", err, self.allocator);
            return err;
        };
    }

    fn createSurface(self: *VulkanContext, window: *c.GLFWwindow) !void {
        const res: vk.Result = c.glfwCreateWindowSurface(self.instance, window, null, &self.surface);
        if (res != .success) {
            printError("Vulkan", "Glfw couldn't create window surface for vulkan context");
            return error.Unknown;
        }
    }

    fn vulkanDebugCallback(
        message_severity: vk.DebugUtilsMessageSeverityFlagsEXT.IntType,
        message_types: vk.DebugUtilsMessageTypeFlagsEXT.IntType,
        p_callback_data: *const vk.DebugUtilsMessengerCallbackDataEXT,
        p_user_data: *c_void,
    ) callconv(vk.vulkan_call_conv) vk.Bool32 {
        printError("Vulkan Validation Layer", std.mem.span(p_callback_data.p_message));
        return 1;
    }

    fn setupDebugMessenger(self: *VulkanContext) !void {
        const create_info: vk.DebugUtilsMessengerCreateInfoEXT = .{
            .flags = .{},
            .message_severity = .{
                .verbose_bit_ext = true,
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

        self.debug_messenger = self.vki.createDebugUtilsMessengerEXT(self.instance, create_info, null) catch |err| {
            printVulkanError("Can't create debug messenger", err, self.allocator);
            return err;
        };
    }

    fn checkDeviceExtensionsSupport(self: *VulkanContext, device: *const vk.PhysicalDevice) !bool {
        var extension_count: u32 = undefined;
        self.vkd.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, null) catch |err| {
            printVulkanError("Can't get count of device extensions", err, self.allocator);
            return err;
        };

        var available_extensions: []vk.ExtensionProperties = self.allocator.alloc(vk.ExtensionProperties, extension_count);
        defer self.allocator.free(available_extensions);
        self.vkd.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, &available_extensions);

        for (required_device_extensions) |req_ext| {
            var extension_found: bool = false;
            for (available_extensions) |ext| {
                if (std.mem.startsWith(u8, ext.extension_name, req_ext)) {
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

    fn isDeviceSuitable(self: *VulkanContext, device: *const vk.PhysicalDevice) !bool {
        const extensions_supported = self.checkDeviceExtensionsSupport(device) catch |err| {
            printVulkanError("Error while checking device extensions", err, self.allocator);
            return err;
        };

        if (!extensions_supported) {
            return false;
        }

        return true;
    }

    fn pickPhysicalDevice(self: *VulkanContext) !void {
        var gpu_count: u32 = undefined;
        self.vki.vkEnumeratePhysicalDevices(self.instance, &gpu_count, null) catch |err| {
            printVulkanError("Can't get physical device count", err, self.allocator);
            return err;
        };

        var physicalDevices: []vk.PhysicalDevice = self.allocator.alloc(vk.PhysicalDevice, gpuCount);
        defer self.allocator.free(physicalDevices);

        self.vki.vkEnumeratePhysicalDevices(self.instance, &gpu_count, physicalDevices) catch |err| {
            printVulkanError("Can't get physical devices information", err, self.allocator);
            return err;
        };

        for (physicalDevices) |device| {
            if (self.isDeviceSuitable(device)) {
                self.physical_device = device;
                self.vkd.vkGetPhysicalDeviceMemoryProperties(self.physical_device, &self.memory_properties);
                return;
            }
        }

        printError("Vulkan", "Can't find suitable device");
        return error.Unknown;
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

        for (availableLayers) |layer| {
            if (std.mem.startsWith(u8, &layer.layer_name, "VK_LAYER_KHRONOS_validation")) {
                return true;
            }
        }

        return false;
    }
};
