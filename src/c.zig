pub usingnamespace @cImport({
    // glfw
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");

    // cimgui
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");

    @cInclude("fira_sans_regular.h");
});

const vk = @import("vk.zig");
