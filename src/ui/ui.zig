const std = @import("std");
const c = @import("../c.zig");

const Application = @import("../application/application.zig").Application;
const Config = @import("../application/config.zig");
const System = @import("../system/system.zig").System;
const UIVulkanContext = @import("ui_vulkan.zig").UIVulkanContext;
const vk = @import("../vk.zig");
const DockSpace = @import("dockspace.zig").DockSpace;

const RGPass = @import("../renderer/render_graph/render_graph_pass.zig").RGPass;
const RenderGraph = @import("../renderer/render_graph/render_graph.zig").RenderGraph;

pub const paletteValues = [_]c_int{
    c.ImGuiCol_Text,
    c.ImGuiCol_TextDisabled,
    c.ImGuiCol_WindowBg,
    c.ImGuiCol_ChildBg,
    c.ImGuiCol_PopupBg,
    c.ImGuiCol_Border,
    c.ImGuiCol_BorderShadow,
    c.ImGuiCol_FrameBg,
    c.ImGuiCol_FrameBgHovered,
    c.ImGuiCol_FrameBgActive,
    c.ImGuiCol_TitleBg,
    c.ImGuiCol_TitleBgActive,
    c.ImGuiCol_TitleBgCollapsed,
    c.ImGuiCol_MenuBarBg,
    c.ImGuiCol_ScrollbarBg,
    c.ImGuiCol_ScrollbarGrab,
    c.ImGuiCol_ScrollbarGrabHovered,
    c.ImGuiCol_ScrollbarGrabActive,
    c.ImGuiCol_CheckMark,
    c.ImGuiCol_SliderGrab,
    c.ImGuiCol_SliderGrabActive,
    c.ImGuiCol_Button,
    c.ImGuiCol_ButtonHovered,
    c.ImGuiCol_ButtonActive,
    c.ImGuiCol_Header,
    c.ImGuiCol_HeaderHovered,
    c.ImGuiCol_HeaderActive,
    c.ImGuiCol_Separator,
    c.ImGuiCol_SeparatorHovered,
    c.ImGuiCol_SeparatorActive,
    c.ImGuiCol_ResizeGrip,
    c.ImGuiCol_ResizeGripHovered,
    c.ImGuiCol_ResizeGripActive,
    c.ImGuiCol_Tab,
    c.ImGuiCol_TabHovered,
    c.ImGuiCol_TabActive,
    c.ImGuiCol_TabUnfocused,
    c.ImGuiCol_TabUnfocusedActive,
    c.ImGuiCol_PlotLines,
    c.ImGuiCol_PlotLinesHovered,
    c.ImGuiCol_PlotHistogram,
    c.ImGuiCol_PlotHistogramHovered,
    c.ImGuiCol_TableHeaderBg,
    c.ImGuiCol_TableBorderStrong,
    c.ImGuiCol_TableBorderLight,
    c.ImGuiCol_TableRowBg,
    c.ImGuiCol_TableRowBgAlt,
    c.ImGuiCol_TextSelectedBg,
    c.ImGuiCol_DragDropTarget,
    c.ImGuiCol_NavHighlight,
    c.ImGuiCol_NavWindowingHighlight,
    c.ImGuiCol_NavWindowingDimBg,
    c.ImGuiCol_ModalWindowDimBg,
};

pub const UI = struct {
    app: *Application,
    name: []const u8,
    imgui_config_path: [:0]const u8,
    system: System,
    vulkan_context: UIVulkanContext,
    dockspace: ?*DockSpace,
    render_pass: RGPass,
    global_render_graph: *RenderGraph,

    paletteFn: ?fn (col: c.ImGuiCol_) c.ImVec4 = null,
    drawFn: fn (ui: *UI) void,

    context: *c.ImGuiContext,

    pub fn init(self: *UI, comptime name: []const u8, allocator: *std.mem.Allocator) void {
        self.dockspace = null;

        self.name = name;

        self.system = System.create(name ++ " System", systemInit, systemDeinit, systemUpdate);

        self.render_pass.init("UI Render Pass", allocator, renderPassInit, renderPassDeinit);
    }

    fn initPalette(self: *UI) void {
        if (self.paletteFn == null)
            return;

        var style: *c.ImGuiStyle = c.igGetStyle();
        for (paletteValues) |p|
            style.Colors[@intCast(usize, p)] = self.paletteFn.?(@intToEnum(c.ImGuiCol_, p));
    }

    fn initScaling(self: *UI, app: *Application) void {
        var width: c_int = undefined;
        var height: c_int = undefined;
        c.glfwGetWindowSize(app.window, &width, &height);

        var io: *c.ImGuiIO = c.igGetIO() orelse unreachable;
        io.DisplaySize = .{ .x = @intToFloat(f32, width), .y = @intToFloat(f32, height) };
        io.DisplayFramebufferScale = .{ .x = 1.0, .y = 1.0 };

        var scale: [2]f32 = undefined;
        c.glfwGetWindowContentScale(app.window, &scale[0], &scale[1]);
        var style: *c.ImGuiStyle = c.igGetStyle();
        c.ImGuiStyle_ScaleAllSizes(style, scale[1]);
    }

    fn renderPassInit(render_pass: *RGPass, render_graph: *RenderGraph) void {
        const self: *UI = @fieldParentPtr(UI, "render_pass", render_pass);
        self.render_pass.appendWriteResource(&render_graph.final_swapchain.rg_resource);
        self.global_render_graph = render_graph;
    }

    fn renderPassDeinit(render_pass: *RGPass, render_graph: *RenderGraph) void {
        const self: *UI = @fieldParentPtr(UI, "render_pass", render_pass);
        self.render_pass.removeWriteResource(&render_graph.final_swapchain.rg_resource);
    }

    fn systemInit(system: *System, app: *Application) void {
        const self: *UI = @fieldParentPtr(UI, "system", system);

        self.app = app;
        const temp_path = Config.global_config.getValidConfigPath("imgui.ini") catch unreachable;
        self.imgui_config_path = Config.global_config.allocator.dupeZ(u8, temp_path) catch unreachable;
        Config.global_config.allocator.free(temp_path);

        self.context = c.igCreateContext(null);

        self.vulkan_context.init(self);

        var io: *c.ImGuiIO = c.igGetIO();
        io.ConfigFlags |= c.ImGuiConfigFlags_DockingEnable;
        io.IniFilename = self.imgui_config_path.ptr;

        self.initPalette();
        self.initScaling(app);
    }

    fn systemDeinit(system: *System) void {
        const self: *UI = @fieldParentPtr(UI, "system", system);

        c.igDestroyContext(self.context);
        self.vulkan_context.deinit();

        Config.global_config.allocator.free(self.imgui_config_path);
    }

    fn systemUpdate(system: *System, elapsed_time: f64) void {
        const self: *UI = @fieldParentPtr(UI, "system", system);

        self.checkFramebufferResized();

        c.igNewFrame();

        if (self.dockspace) |d|
            d.drawBegin();

        self.drawFn(self);

        if (self.dockspace) |d|
            d.drawEnd();

        c.igRender();
        c.igEndFrame();
    }

    pub fn render(system: *System, index: u32, render_graph: *RenderGraph) vk.CommandBuffer {
        const self: *UI = @fieldParentPtr(UI, "system", system);
        return self.vulkan_context.render(index, render_graph);
    }

    fn checkFramebufferResized(self: *UI) void {
        if (!self.app.framebuffer_resized)
            return;

        var width: c_int = undefined;
        var height: c_int = undefined;
        c.glfwGetWindowSize(self.app.window, &width, &height);

        var io: *c.ImGuiIO = c.igGetIO() orelse unreachable;
        io.DisplaySize = .{ .x = @intToFloat(f32, width), .y = @intToFloat(f32, height) };
        io.DisplayFramebufferScale = .{ .x = 1.0, .y = 1.0 };
    }
};
