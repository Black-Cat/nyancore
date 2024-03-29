const std = @import("std");

const c = @import("../c.zig");
const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const Allocator = std.mem.Allocator;

const printError = @import("../application/print_error.zig").printError;
const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

pub fn create(app_name: [:0]const u8, comptime enable_validation: bool, allocator: Allocator) !vk.Instance {
    if (enable_validation) {
        const validation_layers_supported: bool = checkValidationLayerSupport() catch |err| {
            printVulkanError("Error getting information about layers", err);
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
        .api_version = vk.API_VERSION_1_3,
    };

    var glfw_extension_count: u32 = undefined;
    const glfw_extensions: [*c][*c]const u8 = c.glfwGetRequiredInstanceExtensions(&glfw_extension_count);

    const extensions_count: u32 = glfw_extension_count + 1 * @intFromBool(enable_validation);
    var extensions: [][*c]const u8 = allocator.alloc([*c]const u8, extensions_count) catch {
        printError("Vulkan", "Can't allocate memory for extensions");
        return error.HostAllocationError;
    };
    defer allocator.free(extensions);

    var i: usize = 0;
    while (i < glfw_extension_count) : (i += 1)
        extensions[i] = glfw_extensions[i];

    if (enable_validation)
        extensions[i] = "VK_EXT_debug_utils";

    const create_info: vk.InstanceCreateInfo = .{
        .p_application_info = &app_info,
        .enabled_extension_count = extensions_count,
        .pp_enabled_extension_names = @ptrCast(extensions),
        .enabled_layer_count = if (enable_validation) @intCast(vkctxt.validation_layers.len) else 0,
        .pp_enabled_layer_names = if (enable_validation) @ptrCast(&vkctxt.validation_layers) else undefined,
        .flags = .{},
    };

    return vkfn.b.createInstance(&create_info, null) catch |err| {
        printVulkanError("Couldn't create vulkan instance", err);
        return err;
    };
}

pub fn destroy(instance: vk.Instance) void {
    vkfn.i.destroyInstance(instance, null);
}

fn checkValidationLayerSupport() !bool {
    var layerCount: u32 = undefined;

    _ = vkfn.b.enumerateInstanceLayerProperties(&layerCount, null) catch |err| {
        printVulkanError("Can't enumerate instance layer properties for layer support", err);
        return err;
    };

    var available_layers: []vk.LayerProperties = vkctxt.allocator.alloc(vk.LayerProperties, layerCount) catch {
        printError("Vulkan", "Can't allocate memory for available layers");
        return error.HostAllocationError;
    };
    defer vkctxt.allocator.free(available_layers);

    _ = vkfn.b.enumerateInstanceLayerProperties(&layerCount, @ptrCast(available_layers)) catch |err| {
        printVulkanError("Can't enumerate instance layer properties for layer support", err);
        return err;
    };

    for (vkctxt.validation_layers) |validation_layer| {
        var exist: bool = for (available_layers) |layer| {
            if (std.mem.startsWith(u8, layer.layer_name[0..], validation_layer[0..])) {
                break true;
            }
        } else false;

        if (!exist)
            return false;
    }

    return true;
}
