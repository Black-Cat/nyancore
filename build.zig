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
    const imguiFlags = &[_][]const u8{};
    const imguiLib = b.addStaticLibrary("imgui", null);
    imguiLib.linkSystemLibrary("c");
    imguiLib.linkSystemLibrary("c++");
    imguiLib.addIncludeDir(cimgui_path ++ "");
    imguiLib.addIncludeDir(cimgui_path ++ "imgui");
    imguiLib.addCSourceFile(cimgui_path ++ "imgui/imgui.cpp", imguiFlags);
    imguiLib.addCSourceFile(cimgui_path ++ "imgui/imgui_demo.cpp", imguiFlags);
    imguiLib.addCSourceFile(cimgui_path ++ "imgui/imgui_draw.cpp", imguiFlags);
    imguiLib.addCSourceFile(cimgui_path ++ "imgui/imgui_tables.cpp", imguiFlags);
    imguiLib.addCSourceFile(cimgui_path ++ "imgui/imgui_widgets.cpp", imguiFlags);
    imguiLib.addCSourceFile(cimgui_path ++ "cimgui.cpp", imguiFlags);

    nyancoreLib.step.dependOn(&imguiLib.step);
    nyancoreLib.linkLibrary(imguiLib);
    app.addIncludeDir(cimgui_path);
    app.linkLibrary(imguiLib);

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
