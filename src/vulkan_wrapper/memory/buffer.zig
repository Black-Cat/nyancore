const vk = @import("vulkan");

pub const Buffer = struct {
    size: vk.DeviceSize,
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    mappedMemory: *u8,
};
