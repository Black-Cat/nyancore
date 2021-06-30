//const build_options = @import("build_options");

const build_config = @import("build_config.zig");

pub usingnamespace @cImport({
    // glfw
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");

    // cimgui
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
});

const vk = @import("vk.zig");

pub extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
pub extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *GLFWwindow, alocation_callback: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;