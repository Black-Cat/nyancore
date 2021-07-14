const std = @import("std");
const vkgen = @import("third_party/vulkan-zig/generator/index.zig");
const builtin = @import("builtin");

const Builder = std.build.Builder;
const Step = std.build.Step;

pub fn addStaticLibrary(b: *Builder, app: *std.build.LibExeObjStep, comptime path: []const u8, use_vulkan_sdk: bool) *std.build.LibExeObjStep {
    const mode = b.standardReleaseOptions();

    const nyancoreLib = b.addStaticLibrary("nyancore", path ++ "src/main.zig");
    nyancoreLib.setBuildMode(mode);

    nyancoreLib.addBuildOption(bool, "use_vulkan_sdk", use_vulkan_sdk);

    // Vulkan
    const vulkanPackage: std.build.Pkg = .{
        .name = "vulkan",
        .path = path ++ "src/vk.zig",
    };

    nyancoreLib.addPackage(vulkanPackage);
    app.addPackage(vulkanPackage);

    if (use_vulkan_sdk) {
        const vulkan_sdk_path = std.os.getenv("VULKAN_SDK") orelse {
            std.debug.print("[ERR] Can't get VULKAN_SDK environment variable", .{});
            return nyancoreLib;
        };

        const vulkan_sdk_include_path = std.fs.path.join(b.allocator, &[_][]const u8{ vulkan_sdk_path, "include" }) catch unreachable;
        defer b.allocator.free(vulkan_sdk_include_path);

        nyancoreLib.addIncludeDir(vulkan_sdk_include_path);
        app.addIncludeDir(vulkan_sdk_include_path);
    }

    // GLFW
    nyancoreLib.linkSystemLibrary("c");
    nyancoreLib.linkSystemLibrary("glfw");

    // Dear ImGui
    comptime const cimgui_path: []const u8 = path ++ "third_party/cimgui/";
    const imgui_flags = &[_][]const u8{};
    const imgui_lib = b.addStaticLibrary("imgui", null);
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
    comptime const glslang_path: []const u8 = path ++ "third_party/glslang/";
    const glslang_machine_dependent_path: []const u8 = glslang_path ++ "glslang/OSDependent/" ++ (if (builtin.os.tag == .windows) "Windows/" else "Unix/");
    const glslang_flags = &[_][]const u8{};
    const glslang_lib = b.addStaticLibrary("glslang", null);
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
    glslang_lib.addCSourceFile(glslang_machine_dependent_path ++ "ossource.cpp", glslang_flags);

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

pub fn build(b: *Builder) void {
    var test_app = b.addExecutable("test_app", "src/test_app.zig");

    var nyancoreLib = addStaticLibrary(b, test_app, "", true);

    const mode = b.standardReleaseOptions();
    test_app.setBuildMode(mode);
    test_app.linkLibrary(nyancoreLib);
    test_app.linkSystemLibrary("c");
    test_app.linkSystemLibrary("glfw");
    test_app.step.dependOn(&nyancoreLib.step);
    test_app.install();

    const run_target = b.step("run", "Run test app");
    const run = test_app.run();
    run.step.dependOn(b.getInstallStep());
    run_target.dependOn(&run.step);
}
