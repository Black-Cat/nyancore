const std = @import("std");
const builtin = @import("builtin");

const Builder = std.build.Builder;
const Step = std.build.Step;

pub const BuildOptions = struct {
    compile_glfw: bool,
    dev_build: bool,
    enable_tracing: bool,
    panic_on_all_errors: bool,
    use_vulkan_sdk: bool,
};

pub fn addStaticLibrary(
    b: *Builder,
    app: *std.build.LibExeObjStep,
    comptime path: []const u8,
    build_options: BuildOptions,
) *std.build.LibExeObjStep {
    const os_tag = if (app.target.os_tag != null) app.target.os_tag.? else builtin.os.tag;

    const nyancoreLib = b.addStaticLibrary(.{
        .name = "nyancore",
        .root_source_file = .{ .path = path ++ "src/main.zig" },
        .target = app.target,
        .optimize = app.optimize,
    });

    const nyancore_options = b.addOptions();
    nyancore_options.addOption(bool, "compile_glfw", build_options.compile_glfw);
    nyancore_options.addOption(bool, "dev_build", build_options.dev_build);
    nyancore_options.addOption(bool, "enable_tracing", build_options.enable_tracing);
    nyancore_options.addOption(bool, "panic_on_all_errors", build_options.panic_on_all_errors);
    nyancore_options.addOption(bool, "use_vulkan_sdk", build_options.use_vulkan_sdk);
    nyancoreLib.addOptions("nyancore_options", nyancore_options);
    app.addOptions("nyancore_options", nyancore_options);

    var nyancore_module = b.addModule(
        "nyancore",
        .{
            .source_file = .{ .path = path ++ "/src/main.zig" },
            .dependencies = &.{.{
                .name = "nyancore_options",
                .module = nyancore_options.createModule(),
            }},
        },
    );
    app.addModule("nyancore", nyancore_module);

    // Vulkan
    const vulkanModule = b.addModule(
        "vulkan",
        .{ .source_file = .{ .path = path ++ "src/vk.zig" } },
    );

    nyancoreLib.addModule("vulkan", vulkanModule);
    app.addModule("vulkan", vulkanModule);

    if (build_options.use_vulkan_sdk) {
        const vulkan_sdk_path = std.process.getEnvVarOwned(b.allocator, "VULKAN_SDK") catch {
            std.debug.print("[ERR] Can't get VULKAN_SDK environment variable", .{});
            return nyancoreLib;
        };
        defer b.allocator.free(vulkan_sdk_path);

        const vulkan_sdk_include_path = std.fs.path.join(b.allocator, &[_][]const u8{ vulkan_sdk_path, "include" }) catch unreachable;
        defer b.allocator.free(vulkan_sdk_include_path);

        nyancoreLib.addIncludePath(.{ .path = vulkan_sdk_include_path });
        app.addIncludePath(.{ .path = vulkan_sdk_include_path });
    }

    // Vulkan Memory Allocator (VMA)
    const vma_path: []const u8 = path ++ "third_party/vma/";
    const vma_lib = b.addStaticLibrary(.{
        .name = "vma",
        .root_source_file = null,
        .target = app.target,
        .optimize = app.optimize,
    });
    const vma_flags = &[_][]const u8{
        "-std=c++17",
        "-DVMA_STATIC_VULKAN_FUNCTIONS=0",
        "-DVMA_DYNAMIC_VULKAN_FUNCTIONS=1",
        "-DVMA_IMPLEMENTATION",
        if (os_tag == .windows)
            "-DVMA_CALL_PRE=__declspec(dllexport)"
        else
            "-DVMA_CALL_PRE=__attribute__((visibility(\"default\")))",
        "-DVMA_CALL_POST=__cdecl",
    };

    vma_lib.linkSystemLibrary("c");
    vma_lib.linkSystemLibrary("c++");

    vma_lib.addIncludePath(.{ .path = path ++ "third_party/vulkan-headers/include/" });
    vma_lib.addIncludePath(.{ .path = path ++ "third_party/vma/include/" });
    // Can't compile vk_mem_alloc.h header directly, zig chooses c instead of c++
    vma_lib.addCSourceFile(.{
        .file = .{ .path = vma_path ++ "src/VmaUsage.cpp" },
        .flags = vma_flags,
    });

    nyancoreLib.step.dependOn(&vma_lib.step);
    nyancoreLib.linkLibrary(vma_lib);
    app.addIncludePath(.{ .path = vma_path ++ "include/" });
    app.linkLibrary(vma_lib);

    // Tracy
    if (build_options.enable_tracing) {
        const tracy_path: []const u8 = path ++ "third_party/tracy/";
        const tracy_lib = b.addStaticLibrary(.{
            .name = "tracy",
            .root_source_file = null,
            .target = app.target,
            .optimize = app.optimize,
        });
        const tracy_flags = &[_][]const u8{ "-DTRACY_ENABLE", "-DTRACY_NO_CALLSTACK", "-DTRACY_NO_SYSTEM_TRACING" };

        tracy_lib.linkSystemLibrary("c");
        tracy_lib.linkSystemLibrary("c++");
        if (os_tag == .windows) {
            tracy_lib.linkSystemLibrary("advapi32");
            tracy_lib.linkSystemLibrary("user32");
            tracy_lib.linkSystemLibrary("ws2_32");
            tracy_lib.linkSystemLibrary("dbghelp");
        }

        tracy_lib.addIncludePath(.{ .path = tracy_path });
        tracy_lib.addCSourceFile(.{
            .file = .{ .path = tracy_path ++ "TracyClient.cpp" },
            .flags = tracy_flags,
        });

        nyancoreLib.step.dependOn(&tracy_lib.step);
        nyancoreLib.linkLibrary(tracy_lib);
        app.addIncludePath(.{ .path = tracy_path });
        app.linkLibrary(tracy_lib);
    }

    // GLFW
    if (build_options.compile_glfw) {
        const glfw_path: []const u8 = path ++ "third_party/glfw/";
        const glfw_lib = b.addStaticLibrary(.{
            .name = "glfw",
            .root_source_file = null,
            .target = app.target,
            .optimize = app.optimize,
        });

        const glfw_flags = &[_][]const u8{
            switch (os_tag) {
                .windows => "-D_GLFW_WIN32",
                .macos => "-D_GLFW_COCA",
                else => "-D_GLFW_X11", // -D_GLFW_WAYLAND
            },
        };
        glfw_lib.linkSystemLibrary("c");
        glfw_lib.addIncludePath(.{ .path = glfw_path ++ "include" });
        glfw_lib.addCSourceFiles(&[_][]const u8{
            glfw_path ++ "src/context.c",
            glfw_path ++ "src/egl_context.c",
            glfw_path ++ "src/init.c",
            glfw_path ++ "src/input.c",
            glfw_path ++ "src/monitor.c",
            glfw_path ++ "src/null_init.c",
            glfw_path ++ "src/null_joystick.c",
            glfw_path ++ "src/null_monitor.c",
            glfw_path ++ "src/null_window.c",
            glfw_path ++ "src/osmesa_context.c",
            glfw_path ++ "src/platform.c",
            glfw_path ++ "src/vulkan.c",
            glfw_path ++ "src/window.c",
        }, glfw_flags);
        glfw_lib.addCSourceFiles(switch (os_tag) {
            .windows => &[_][]const u8{
                glfw_path ++ "src/wgl_context.c",
                glfw_path ++ "src/win32_init.c",
                glfw_path ++ "src/win32_joystick.c",
                glfw_path ++ "src/win32_module.c",
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
                glfw_path ++ "src/posix_module.c",
                glfw_path ++ "src/posix_poll.c",
            },
            else => &[_][]const u8{
                glfw_path ++ "src/posix_poll.c",
                glfw_path ++ "src/posix_module.c",
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
        app.addIncludePath(.{ .path = glfw_path ++ "include" });
        app.linkLibrary(glfw_lib);
    }

    // Dear ImGui
    const cimgui_path: []const u8 = path ++ "third_party/cimgui/";
    const imgui_flags = &[_][]const u8{};
    const imgui_lib = b.addStaticLibrary(.{
        .name = "imgui",
        .root_source_file = null,
        .target = app.target,
        .optimize = app.optimize,
    });

    imgui_lib.linkSystemLibrary("c");
    imgui_lib.linkSystemLibrary("c++");

    imgui_lib.addIncludePath(.{ .path = cimgui_path ++ "" });
    imgui_lib.addIncludePath(.{ .path = cimgui_path ++ "imgui" });

    imgui_lib.addCSourceFiles(&[_][]const u8{
        cimgui_path ++ "imgui/imgui.cpp",
        cimgui_path ++ "imgui/imgui_demo.cpp",
        cimgui_path ++ "imgui/imgui_draw.cpp",
        cimgui_path ++ "imgui/imgui_tables.cpp",
        cimgui_path ++ "imgui/imgui_widgets.cpp",
        cimgui_path ++ "cimgui.cpp",
    }, imgui_flags);

    nyancoreLib.step.dependOn(&imgui_lib.step);
    nyancoreLib.linkLibrary(imgui_lib);
    app.addIncludePath(.{ .path = cimgui_path });
    app.linkLibrary(imgui_lib);

    // glslang
    const glslang_path: []const u8 = path ++ "third_party/glslang/";
    const glslang_machine_dependent_path = if (os_tag == .windows) glslang_path ++ "glslang/OSDependent/Windows/" else glslang_path ++ "glslang/OSDependent/Unix/";
    const glslang_flags = &[_][]const u8{"-fno-sanitize=undefined"};
    const glslang_lib = b.addStaticLibrary(.{
        .name = "glslang",
        .root_source_file = null,
        .target = app.target,
        .optimize = app.optimize,
    });

    glslang_lib.linkSystemLibrary("c");
    glslang_lib.linkSystemLibrary("c++");

    glslang_lib.addIncludePath(.{ .path = glslang_path });
    glslang_lib.addCSourceFiles(&[_][]const u8{
        glslang_path ++ "glslang/CInterface/glslang_c_interface.cpp",
        glslang_path ++ "glslang/GenericCodeGen/CodeGen.cpp",
        glslang_path ++ "glslang/GenericCodeGen/Link.cpp",
        glslang_path ++ "glslang/MachineIndependent/attribute.cpp",
        glslang_path ++ "glslang/MachineIndependent/Constant.cpp",
        glslang_path ++ "glslang/MachineIndependent/Initialize.cpp",
        glslang_path ++ "glslang/MachineIndependent/InfoSink.cpp",
        glslang_path ++ "glslang/MachineIndependent/Intermediate.cpp",
        glslang_path ++ "glslang/MachineIndependent/intermOut.cpp",
        glslang_path ++ "glslang/MachineIndependent/IntermTraverse.cpp",
        glslang_path ++ "glslang/MachineIndependent/iomapper.cpp",
        glslang_path ++ "glslang/MachineIndependent/glslang_tab.cpp",
        glslang_path ++ "glslang/MachineIndependent/linkValidate.cpp",
        glslang_path ++ "glslang/MachineIndependent/limits.cpp",
        glslang_path ++ "glslang/MachineIndependent/parseConst.cpp",
        glslang_path ++ "glslang/MachineIndependent/ParseContextBase.cpp",
        glslang_path ++ "glslang/MachineIndependent/preprocessor/Pp.cpp",
        glslang_path ++ "glslang/MachineIndependent/preprocessor/PpAtom.cpp",
        glslang_path ++ "glslang/MachineIndependent/preprocessor/PpContext.cpp",
        glslang_path ++ "glslang/MachineIndependent/preprocessor/PpScanner.cpp",
        glslang_path ++ "glslang/MachineIndependent/preprocessor/PpTokens.cpp",
        glslang_path ++ "glslang/MachineIndependent/propagateNoContraction.cpp",
        glslang_path ++ "glslang/MachineIndependent/reflection.cpp",
        glslang_path ++ "glslang/MachineIndependent/RemoveTree.cpp",
        glslang_path ++ "glslang/MachineIndependent/Scan.cpp",
        glslang_path ++ "glslang/MachineIndependent/ShaderLang.cpp",
        glslang_path ++ "glslang/MachineIndependent/SpirvIntrinsics.cpp",
        glslang_path ++ "glslang/MachineIndependent/SymbolTable.cpp",
        glslang_path ++ "glslang/MachineIndependent/ParseHelper.cpp",
        glslang_path ++ "glslang/MachineIndependent/PoolAlloc.cpp",
        glslang_path ++ "glslang/MachineIndependent/Versions.cpp",
        glslang_path ++ "SPIRV/CInterface/spirv_c_interface.cpp",
        glslang_path ++ "SPIRV/GlslangToSpv.cpp",
        glslang_path ++ "SPIRV/InReadableOrder.cpp",
        glslang_path ++ "SPIRV/Logger.cpp",
        glslang_path ++ "SPIRV/SpvBuilder.cpp",
        glslang_path ++ "SPIRV/SpvPostProcess.cpp",
    }, glslang_flags);
    const osssource_path = std.fs.path.join(b.allocator, &.{ glslang_machine_dependent_path, "ossource.cpp" }) catch unreachable;
    glslang_lib.addCSourceFile(.{ .file = .{ .path = osssource_path }, .flags = glslang_flags });

    nyancoreLib.step.dependOn(&glslang_lib.step);
    nyancoreLib.linkLibrary(glslang_lib);
    app.addIncludePath(.{ .path = glslang_path ++ "glslang/Include" });
    app.linkLibrary(glslang_lib);

    // Fonts
    nyancoreLib.addIncludePath(.{ .path = path ++ "third_party/fonts/" });
    app.addIncludePath(.{ .path = path ++ "third_party/fonts/" });

    // Enet
    const enet_path: []const u8 = path ++ "third_party/enet/";
    const enet_flags = switch (os_tag) {
        .windows => &[_][]const u8{
            "-fno-sanitize=undefined",
            "-DHAS_GETNAMEINFO=1",
            "-DHAS_INET_PTON=1",
            "-DHAS_INET_NTOP=1",
            "-DHAS_MSGHDR_FLAGS=1",
        },
        else => &[_][]const u8{
            "-fno-sanitize=undefined",
            "-DHAS_FCNTL=1",
            "-DHAS_POLL=1",
            "-DHAS_GETADDRINFO=1",
            "-DHAS_GETNAMEINFO=1",
            "-DHAS_GETHOSTBYNAME_R=1",
            "-DHAS_GETHOSTBYADDR_R=1",
            "-DHAS_INET_PTON=1",
            "-DHAS_INET_NTOP=1",
            "-DHAS_MSGHDR_FLAGS=1",
            "-DHAS_SOCKLEN_T=1",
        },
    };
    const enet_lib = b.addStaticLibrary(.{
        .name = "enet",
        .root_source_file = null,
        .target = app.target,
        .optimize = app.optimize,
    });

    enet_lib.linkSystemLibrary("c");

    enet_lib.addIncludePath(.{ .path = enet_path ++ "include" });

    enet_lib.addCSourceFiles(&[_][]const u8{
        enet_path ++ "callbacks.c",
        enet_path ++ "compress.c",
        enet_path ++ "host.c",
        enet_path ++ "list.c",
        enet_path ++ "packet.c",
        enet_path ++ "peer.c",
        enet_path ++ "protocol.c",
        enet_path ++ "unix.c",
        enet_path ++ "win32.c",
    }, enet_flags);

    nyancoreLib.step.dependOn(&enet_lib.step);
    nyancoreLib.linkLibrary(enet_lib);
    app.addIncludePath(.{ .path = enet_path ++ "include" });
    app.linkLibrary(enet_lib);

    b.installArtifact(nyancoreLib);

    return nyancoreLib;
}

pub fn build(b: *Builder) void {
    const target: std.zig.CrossTarget = b.standardTargetOptions(.{});
    const mode: std.builtin.Mode = b.standardReleaseOptions();

    const vulkan_validation: bool = b.option(bool, "vulkan-validation", "Use vulkan validation layer, useful for vulkan development. Needs Vulkan SDK") orelse false;
    const enable_tracing: bool = b.option(bool, "enable-tracing", "Enable tracing with tracy v0.8") orelse false;
    const panic_on_all_errors: bool = b.option(bool, "panic-on-all-errors", "Panic on non critical errors") orelse false;

    buildExe(
        b,
        target,
        mode,
        vulkan_validation,
        enable_tracing,
        panic_on_all_errors,
        "nyan_mesh_viewer",
        "src/main_mesh_viewer.zig",
        "run-mesh-viewer",
        "Run mesh viewer",
    );
}

pub fn buildExe(
    b: *Builder,
    target: std.zig.CrossTarget,
    mode: std.builtin.Mode,
    vulkan_validation: bool,
    enable_tracing: bool,
    panic_on_all_errors: bool,
    name: []const u8,
    main_path: []const u8,
    step_name: []const u8,
    step_description: []const u8,
) void {
    var exe = b.addExecutable(name, main_path);

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkSystemLibrary("c");

    var nyancoreLib = addStaticLibrary(b, exe, "./", vulkan_validation, enable_tracing, panic_on_all_errors, true);

    exe.linkLibrary(nyancoreLib);
    exe.step.dependOn(&nyancoreLib.step);

    exe.install();

    const run_target = b.step(step_name, step_description);
    const run = exe.run();
    run.step.dependOn(b.getInstallStep());
    run_target.dependOn(&run.step);
}
