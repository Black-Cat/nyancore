const nyancore_options = @import("nyancore_options");

pub usingnamespace @cImport({
    // glfw
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");

    // cimgui
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");

    // tracy
    if (nyancore_options.enable_tracing) {
        @cDefine("TRACY_ENABLE", {});
        @cDefine("TRACY_NO_CALLSTACK", {});
        @cInclude("TracyC.h");
    }

    @cInclude("fira_sans_regular.h");
});

const vk = @import("vk.zig");
