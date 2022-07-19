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
        .enabled_layer_count = if (nyancore_options.use_vulkan_sdk) @intCast(u32, std.mem.len(vkctxt.validation_layers)) else 0,
        .pp_enabled_layer_names = if (nyancore_options.use_vulkan_sdk) @ptrCast([*]const [*:0]const u8, &vkctxt.validation_layers) else undefined,
        .enabled_extension_count = @intCast(u32, std.mem.len(vkctxt.required_device_extensions)),
        .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, &vkctxt.required_device_extensions),
    };

    return vkfn.i.createDevice(physical_device.vk_ref, create_info, null) catch |err| {
        printVulkanError("Can't create device", err);
        return err;
    };
}

pub fn destroy(device: vk.Device) void {
    vkfn.d.destroyDevice(device, null);
}
