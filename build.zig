const std = @import("std");
const vkgen = @import("third_party/vulkan-zig/generator/index.zig");

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
    nyancoreLib.linkLibC();
    nyancoreLib.install();

    // Vulkan
    const gen = vkgen.VkGenerateStep.init(b, "resources/vk.xml", "vk.zig");
    nyancoreLib.step.dependOn(&gen.step);
    nyancoreLib.addPackage(gen.package);

    const res = ResourceGenStep.init(b, "resources.zig");
    //res.addShader("ui_vert", "resources/shaders/ui.vert");
    //res.addShader("ui_frag", "resources/shaders/ui.frag");
    nyancoreLib.step.dependOn(&res.step);
    nyancoreLib.addPackage(res.package);

    // GLFW
    nyancoreLib.linkSystemLibrary("glfw");
    nyancoreLib.addPackagePath("glfw", "third_party/glfw-zig/glfw.zig");

    // Dear ImGui
    const imguiLib = b.addStaticLibrary("imgui", null);
    imguiLib.linkLibC();
    imguiLib.addIncludeDir("third_party/cimgui/");
    imguiLib.addIncludeDir("third_party/cimgui/imgui");
    imguiLib.addCSourceFile("third_party/cimgui/imgui/imgui.cpp", &[_][]const u8{});
    imguiLib.addCSourceFile("third_party/cimgui/cimgui.cpp", &[_][]const u8{});
    nyancoreLib.step.dependOn(&imguiLib.step);
    nyancoreLib.linkLibrary(imguiLib);
}
