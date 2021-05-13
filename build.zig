const std = @import("std");
const vkgen = @import("third_party/vulkan-zig/generator/index.zig");
const builtin = @import("builtin");

const Builder = std.build.Builder;
const Step = std.build.Step;

pub const ResourceGenStep = struct {
    step: Step,
    shader_step: *vkgen.ShaderCompileStep,
    builder: *Builder,
    package: std.build.Pkg,
    resources: std.ArrayList(u8),

    pub fn init(builder: *Builder, out: []const u8) *ResourceGenStep {
        const self = builder.allocator.create(ResourceGenStep) catch unreachable;
        const full_out_path = std.fs.path.join(builder.allocator, &[_][]const u8{
            builder.build_root,
            builder.cache_root,
            out,
        }) catch unreachable;

        self.* = .{
            .step = Step.init(.Custom, "resources", builder.allocator, make),
            .shader_step = vkgen.ShaderCompileStep.init(builder, &[_][]const u8{ "glslc", "--target-env=vulkan1.2" }),
            .builder = builder,
            .package = .{
                .name = "resources",
                .path = full_out_path,
                .dependencies = null,
            },
            .resources = std.ArrayList(u8).init(builder.allocator),
        };

        self.step.dependOn(&self.shader_step.step);
        return self;
    }

    fn renderPath(self: *ResourceGenStep, path: []const u8, writer: anytype) void {
        const separators = &[_]u8{ std.fs.path.sep_windows, std.fs.path.sep_posix };
        var i: usize = 0;
        while (std.mem.indexOfAnyPos(u8, path, i, separators)) |j| {
            writer.writeAll(path[i..j]) catch unreachable;
            switch (std.fs.path.sep) {
                std.fs.path.sep_windows => writer.writeAll("\\\\") catch unreachable,
                std.fs.path.sep_posix => writer.writeByte(std.fs.path.sep_posix) catch unreachable,
                else => unreachable,
            }

            i = j + 1;
        }

        writer.writeAll(path[i..]) catch unreachable;
    }

    pub fn addShader(self: *ResourceGenStep, name: []const u8, source: []const u8) void {
        const shader_out_path = self.shader_step.add(source);
        var writer = self.resources.writer();

        writer.print("pub const {s} = @embedFile(\"", .{name}) catch unreachable;
        self.renderPath(shader_out_path, writer);
        writer.writeAll("\");\n") catch unreachable;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(ResourceGenStep, "step", step);
        const cwd = std.fs.cwd();

        const dir = std.fs.path.dirname(self.package.path).?;
        try cwd.makePath(dir);
        try cwd.writeFile(self.package.path, self.resources.items);
    }
};

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const nyancoreLib = b.addStaticLibrary("nyancore", "src/main.zig");
    nyancoreLib.setBuildMode(mode);

    var test_app = b.addExecutable("test_app", "src/test_app.zig");
    test_app.setBuildMode(mode);
    test_app.linkLibrary(nyancoreLib);
    test_app.linkSystemLibrary("c");
    test_app.linkSystemLibrary("glfw");
    test_app.step.dependOn(&nyancoreLib.step);
    test_app.install();

    const use_vulkan_sdk = b.option(bool, "use_vulkan_sdk", "Use vulkan SDK") orelse true;
    nyancoreLib.addBuildOption(bool, "use_vulkan_sdk", use_vulkan_sdk);

    // Vulkan
    const gen = vkgen.VkGenerateStep.init(b, "resources/vk.xml", "vk.zig");
    nyancoreLib.step.dependOn(&gen.step);
    nyancoreLib.addPackage(gen.package);
    test_app.addPackage(gen.package);
    if (use_vulkan_sdk) {
        const vulkan_sdk_path = std.os.getenv("VULKAN_SDK") orelse {
            std.debug.print("[ERR] Can't get VULKAN_SDK environment variable", .{});
            return;
        };

        const vulkan_sdk_include_path = std.fs.path.join(b.allocator, &[_][]const u8{ vulkan_sdk_path, "include" }) catch unreachable;
        defer b.allocator.free(vulkan_sdk_include_path);

        nyancoreLib.addIncludeDir(vulkan_sdk_include_path);
        test_app.addIncludeDir(vulkan_sdk_include_path);
    }

    const res = ResourceGenStep.init(b, "resources.zig");
    //res.addShader("ui_vert", "resources/shaders/ui.vert");
    //res.addShader("ui_frag", "resources/shaders/ui.frag");
    nyancoreLib.step.dependOn(&res.step);
    nyancoreLib.addPackage(res.package);

    // GLFW
    nyancoreLib.linkSystemLibrary("c");
    nyancoreLib.linkSystemLibrary("glfw");

    // Dear ImGui
    const imguiFlags = &[_][]const u8{};
    const imguiLib = b.addStaticLibrary("imgui", null);
    imguiLib.linkSystemLibrary("c");
    imguiLib.linkSystemLibrary("c++");
    imguiLib.addIncludeDir("third_party/cimgui/");
    imguiLib.addIncludeDir("third_party/cimgui/imgui");
    imguiLib.addCSourceFile("third_party/cimgui/imgui/imgui.cpp", imguiFlags);
    imguiLib.addCSourceFile("third_party/cimgui/imgui/imgui_demo.cpp", imguiFlags);
    imguiLib.addCSourceFile("third_party/cimgui/imgui/imgui_draw.cpp", imguiFlags);
    imguiLib.addCSourceFile("third_party/cimgui/imgui/imgui_tables.cpp", imguiFlags);
    imguiLib.addCSourceFile("third_party/cimgui/imgui/imgui_widgets.cpp", imguiFlags);
    imguiLib.addCSourceFile("third_party/cimgui/cimgui.cpp", imguiFlags);

    nyancoreLib.step.dependOn(&imguiLib.step);
    nyancoreLib.linkLibrary(imguiLib);
    test_app.addIncludeDir("third_party/cimgui/");
    test_app.linkLibrary(imguiLib);

    nyancoreLib.install();

    const run_target = b.step("run", "Run test app");
    const run = test_app.run();
    run.step.dependOn(b.getInstallStep());
    run_target.dependOn(&run.step);
}
