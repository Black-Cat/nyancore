const vk = @import("../vk.zig");

pub const FncBase = struct {
    vkCreateInstance: vk.PfnCreateInstance,
    vkEnumerateInstanceLayerProperties: vk.PfnEnumerateInstanceLayerProperties,
    usingnamespace vk.BaseWrapper(@This());
};

pub var b: FncBase = undefined;
