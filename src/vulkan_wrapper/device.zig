const nyancore_options = @import("nyancore_options");

const std = @import("std");

const vk = @import("../vk.zig");

const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const printVulkanError = @import("print_vulkan_error.zig").printVulkanError;

const PhysicalDevice = @import("physical_device.zig").PhysicalDevice;

pub fn create(physical_device: *PhysicalDevice) !vk.Device {
    var queue_indices: [3]u32 = [_]u32{
        physical_device.family_indices.present_family,
        physical_device.family_indices.graphics_family,
        physical_device.family_indices.compute_family,
    };

    std.sort.heap(u32, queue_indices[0..], {}, comptime std.sort.asc(u32));

    var queue_create_info: [3]vk.DeviceQueueCreateInfo = [_]vk.DeviceQueueCreateInfo{ undefined, undefined, undefined };
    var queue_create_info_count: usize = 0;
    var last_family: u32 = undefined;
    const queue_priority: f32 = 1.0;

    for (queue_indices) |qi| {
        if (qi != last_family) {
            queue_create_info[queue_create_info_count] = .{
                .flags = .{},
                .queue_family_index = qi,
                .queue_count = 1,
                .p_queue_priorities = @ptrCast(&queue_priority),
            };
            last_family = qi;
            queue_create_info_count += 1;
        }
    }

    var shader_draw_parameters: vk.PhysicalDeviceShaderDrawParametersFeatures = .{ .shader_draw_parameters = vk.TRUE };
    const create_info: vk.DeviceCreateInfo = .{
        .flags = .{},
        .p_queue_create_infos = @ptrCast(&queue_create_info),
        .queue_create_info_count = @intCast(queue_create_info_count),
        .p_enabled_features = null,
        .enabled_layer_count = if (nyancore_options.use_vulkan_sdk) @intCast(vkctxt.validation_layers.len) else 0,
        .pp_enabled_layer_names = if (nyancore_options.use_vulkan_sdk) @ptrCast(&vkctxt.validation_layers) else undefined,
        .enabled_extension_count = @intCast(vkctxt.required_device_extensions.len),
        .pp_enabled_extension_names = @ptrCast(&vkctxt.required_device_extensions),
        .p_next = &shader_draw_parameters,
    };

    return vkfn.i.createDevice(physical_device.vk_ref, &create_info, null) catch |err| {
        printVulkanError("Can't create device", err);
        return err;
    };
}

pub fn destroy(device: vk.Device) void {
    vkfn.d.destroyDevice(device, null);
}
