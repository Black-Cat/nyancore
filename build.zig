const std = @import("std");
const builtin = @import("builtin");

const Builder = std.build.Builder;
const Step = std.build.Step;

pub fn addStaticLibrary(b: *Builder, app: *std.build.LibExeObjStep, comptime path: []const u8, use_vulkan_sdk: bool) *std.build.LibExeObjStep {
    const os_tag = if (app.target.os_tag != null) app.target.os_tag.? else builtin.os.tag;

    const nyancoreLib = b.addStaticLibrary("nyancore", path ++ "src/main.zig");
    nyancoreLib.setBuildMode(app.build_mode);
    nyancoreLib.setTarget(app.target);

    const nyancore_options = b.addOptions();
    nyancore_options.addOption(bool, "use_vulkan_sdk", use_vulkan_sdk);
    nyancoreLib.addOptions("nyancore_options", nyancore_options);
    app.addOptions("nyancore_options", nyancore_options);
    app.addPackage(.{
        .name = "nyancore",
        .path = .{ .path = path ++ "/src/main.zig" },
        .dependencies = &[_]std.build.Pkg{
            nyancore_options.getPackage("nyancore_options"),
        },
    });

    // Vulkan
    const vulkanPackage: std.build.Pkg = .{
        .name = "vulkan",
        .path = .{ .path = path ++ "src/vk.zig" },
    };

    nyancoreLib.addPackage(vulkanPackage);
    app.addPackage(vulkanPackage);

    if (use_vulkan_sdk) {
        const vulkan_sdk_path = std.process.getEnvVarOwned(b.allocator, "VULKAN_SDK") catch {
            std.debug.print("[ERR] Can't get VULKAN_SDK environment variable", .{});
            return nyancoreLib;
        };
        defer b.allocator.free(vulkan_sdk_path);

        const vulkan_sdk_include_path = std.fs.path.join(b.allocator, &[_][]const u8{ vulkan_sdk_path, "include" }) catch unreachable;
        defer b.allocator.free(vulkan_sdk_include_path);

        nyancoreLib.addIncludeDir(vulkan_sdk_include_path);
        app.addIncludeDir(vulkan_sdk_include_path);
    }

    // GLFW
    const glfw_path: []const u8 = path ++ "third_party/glfw/";
    const glfw_lib = b.addStaticLibrary("glfw", null);
    glfw_lib.setTarget(app.target);
    glfw_lib.setBuildMode(app.build_mode);

    const glfw_flags = &[_][]const u8{
        switch (os_tag) {
            .windows => "-D_GLFW_WIN32",
            .macos => "-D_GLFW_COCA",
            else => "-D_GLFW_X11", // -D_GLFW_WAYLAND
        },
    };
    glfw_lib.linkSystemLibrary("c");
    glfw_lib.addIncludeDir(glfw_path ++ "include");
    glfw_lib.addCSourceFiles(&[_][]const u8{
        glfw_path ++ "src/context.c",
        glfw_path ++ "src/egl_context.c",
        glfw_path ++ "src/init.c",
        glfw_path ++ "src/input.c",
        glfw_path ++ "src/monitor.c",
        glfw_path ++ "src/osmesa_context.c",
        glfw_path ++ "src/vulkan.c",
        glfw_path ++ "src/window.c",
    }, glfw_flags);
    glfw_lib.addCSourceFiles(switch (os_tag) {
        .windows => &[_][]const u8{
            glfw_path ++ "src/wgl_context.c",
            glfw_path ++ "src/win32_init.c",
            glfw_path ++ "src/win32_joystick.c",
            glfw_path ++ "src/win32_monitor.c",
            glfw_path ++ "src/win32_thread.c",
            glfw_path ++ "src/win32_time.c",
            glfw_path ++ "src/win32_window.c",
        },
        .macos => &[_][]const u8{
            glfw_path ++ "src/cocoa_init.m",
            glfw_path ++ "src/cocoa_joystick.m",
            glfw_path ++ "src/cocoa_monitor.m",
            glfw_path ++ "src/cocoa_time.c",
            glfw_path ++ "src/cocoa_window.m",
            glfw_path ++ "src/nsgl_context.m",
            glfw_path ++ "src/posix_thread.c",
        },
        else => &[_][]const u8{
            glfw_path ++ "src/posix_thread.c",
            glfw_path ++ "src/posix_time.c",
            glfw_path ++ "src/linux_joystick.c",

            // X11
            glfw_path ++ "src/glx_context.c",
            glfw_path ++ "src/x11_init.c",
            glfw_path ++ "src/x11_monitor.c",
            glfw_path ++ "src/x11_window.c",
            glfw_path ++ "src/xkb_unicode.c",

            // Wayland
            //glfw_path ++ "src/wl_init.c",
            //glfw_path ++ "src/wl_monitor.c",
            //glfw_path ++ "src/wl_window.c",
        },
    }, glfw_flags);

    if (os_tag != .windows) {
        glfw_lib.linkSystemLibrary("X11");
        glfw_lib.linkSystemLibrary("xcb");
        glfw_lib.linkSystemLibrary("Xau");
        glfw_lib.linkSystemLibrary("Xdmcp");
    } else {
        glfw_lib.linkSystemLibrary("gdi32");
    }

    nyancoreLib.step.dependOn(&glfw_lib.step);
    nyancoreLib.linkLibrary(glfw_lib);
    app.addIncludeDir(glfw_path ++ "include");
    app.linkLibrary(glfw_lib);

    // Dear ImGui
    const cimgui_path: []const u8 = path ++ "third_party/cimgui/";
    const imgui_flags = &[_][]const u8{};
    const imgui_lib = b.addStaticLibrary("imgui", null);
    imgui_lib.setTarget(app.target);
    imgui_lib.setBuildMode(app.build_mode);
    imgui_lib.linkSystemLibrary("c");
    imgui_lib.linkSystemLibrary("c++");
    imgui_lib.addIncludeDir(cimgui_path ++ "");
    imgui_lib.addIncludeDir(cimgui_path ++ "imgui");
    imgui_lib.addCSourceFile(cimgui_path ++ "imgui/imgui.cpp", imgui_flags);
    imgui_lib.addCSourceFile(cimgui_path ++ "imgui/imgui_demo.cpp", imgui_flags);
    imgui_lib.addCSourceFile(cimgui_path ++ "imgui/imgui_draw.cpp", imgui_flags);
    imgui_lib.addCSourceFile(cimgui_path ++ "imgui/imgui_tables.cpp", imgui_flags);
    imgui_lib.addCSourceFile(cimgui_path ++ "imgui/imgui_widgets.cpp", imgui_flags);
    imgui_lib.addCSourceFile(cimgui_path ++ "cimgui.cpp", imgui_flags);

    nyancoreLib.step.dependOn(&imgui_lib.step);
    nyancoreLib.linkLibrary(imgui_lib);
    app.addIncludeDir(cimgui_path);
    app.linkLibrary(imgui_lib);

    // glslang
    const glslang_path: []const u8 = path ++ "third_party/glslang/";
    const glslang_machine_dependent_path = if (os_tag == .windows) glslang_path ++ "glslang/OSDependent/Windows/" else glslang_path ++ "glslang/OSDependent/Unix/";
    const glslang_flags = &[_][]const u8{};
    const glslang_lib = b.addStaticLibrary("glslang", null);
    glslang_lib.setTarget(app.target);
    glslang_lib.setBuildMode(app.build_mode);
    glslang_lib.linkSystemLibrary("c");
    glslang_lib.linkSystemLibrary("c++");
    glslang_lib.addIncludeDir(glslang_path);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/CInterface/glslang_c_interface.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/GenericCodeGen/CodeGen.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/GenericCodeGen/Link.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/attribute.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/Constant.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/Initialize.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/InfoSink.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/Intermediate.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/intermOut.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/IntermTraverse.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/iomapper.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/glslang_tab.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/linkValidate.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/limits.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/parseConst.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/ParseContextBase.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/preprocessor/Pp.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/preprocessor/PpAtom.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/preprocessor/PpContext.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/preprocessor/PpScanner.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/preprocessor/PpTokens.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/propagateNoContraction.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/reflection.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/RemoveTree.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/Scan.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/ShaderLang.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/SpirvIntrinsics.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/SymbolTable.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/ParseHelper.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/PoolAlloc.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "glslang/MachineIndependent/Versions.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "OGLCompilersDLL/InitializeDll.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "SPIRV/CInterface/spirv_c_interface.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "SPIRV/GlslangToSpv.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "SPIRV/InReadableOrder.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "SPIRV/Logger.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "SPIRV/SpvBuilder.cpp", glslang_flags);
    glslang_lib.addCSourceFile(glslang_path ++ "SPIRV/SpvPostProcess.cpp", glslang_flags);
    const osssource_path = std.fs.path.join(b.allocator, &.{ glslang_machine_dependent_path, "ossource.cpp" }) catch unreachable;
    glslang_lib.addCSourceFile(osssource_path, glslang_flags);

    nyancoreLib.step.dependOn(&glslang_lib.step);
    nyancoreLib.linkLibrary(glslang_lib);
    app.addIncludeDir(glslang_path ++ "glslang/Include");
    app.linkLibrary(glslang_lib);

    // Fonts
    nyancoreLib.addIncludeDir(path ++ "third_party/fonts/");
    app.addIncludeDir(path ++ "third_party/fonts/");

    nyancoreLib.install();

    return nyancoreLib;
}
