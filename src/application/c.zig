//const build_options = @import("build_options");

pub usingnamespace @cImport({
    // Build options are not yet supported in non main file

    //if (build_options.use_vulkan_sdk) {
    //    @cDefine("GLFW_INCLUDE_VULKAN", {});
    //} else {
    //    @cDefine("GLFW_INCLUDE_NONE", {});
    //}
    @cDefine("GLFW_INCLUDE_VULKAN", {});
    @cInclude("GLFW/glfw3.h");

    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", {});
    @cInclude("cimgui.h");
});
