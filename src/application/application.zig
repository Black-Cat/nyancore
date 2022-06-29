const builtin = @import("builtin");
const c = @import("../c.zig");
const ico = @import("../image/ico.zig");
const nyancore_options = @import("nyancore_options");
const rg = @import("../renderer/render_graph/render_graph.zig");
const std = @import("std");
const tracy = @import("../tracy.zig");

const Allocator = std.mem.Allocator;
const Global = @import("../global.zig");
const Config = @import("config.zig").Config;
const Image = @import("../image/image.zig").Image;
pub const System = @import("../system/system.zig").System;
const printError = @import("print_error.zig").printError;
const printErrorNoPanic = @import("print_error.zig").printErrorNoPanic;

const imgui_mouse_button_count: usize = 5;

const ApplicationError = error{
    GLFW_FAILED_TO_INIT,
    GLFW_FAILED_TO_CREATE_WINDOW,
};

var application_glfw_map: std.AutoHashMap(*c.GLFWwindow, *Application) = undefined;
pub fn initGlobalData(allocator: Allocator) void {
    application_glfw_map = std.AutoHashMap(*c.GLFWwindow, *Application).init(allocator);
}
pub fn deinitGlobalData() void {
    application_glfw_map.deinit();
}

pub var app: Application = undefined;

pub const Application = struct {
    pub const DelayedTask = struct {
        task: fn (context: *anyopaque) void,
        context: *anyopaque,
        delay: f64,
    };

    allocator: Allocator,
    config: *Config,
    config_file: []const u8,
    name: [:0]const u8,
    mouse_just_pressed: [imgui_mouse_button_count]bool,
    systems: []*System,
    window: *c.GLFWwindow,
    framebuffer_resized: bool,
    args: std.StringHashMap([]const u8),
    delayed_tasks: std.ArrayList(DelayedTask),

    pub fn init(self: *Application, comptime name: [:0]const u8, allocator: Allocator, systems: []*System) void {
        self.allocator = allocator;
        self.mouse_just_pressed = [_]bool{false} ** imgui_mouse_button_count;
        self.name = name;
        self.systems = systems;
        self.window = undefined;
        self.framebuffer_resized = false;

        self.config_file = name ++ ".conf";
        self.config = &Global.config;
        self.config.init(self.allocator, self.name, self.config_file);

        self.args = parseArgs(self.allocator);
        self.delayed_tasks = std.ArrayList(DelayedTask).init(allocator);
    }

    pub fn deinit(self: *Application) void {
        var args_iter = self.args.iterator();
        while (args_iter.next()) |arg| {
            self.allocator.free(arg.key_ptr.*);
            self.allocator.free(arg.value_ptr.*);
        }
        self.args.deinit();
        self.delayed_tasks.deinit();
    }

    fn parseArgs(allocator: Allocator) std.StringHashMap([]const u8) {
        var map: std.StringHashMap([]const u8) = std.StringHashMap([]const u8).init(allocator);

        const args: []const [:0]u8 = std.process.argsAlloc(allocator) catch unreachable;
        defer std.process.argsFree(allocator, args);

        var ind: usize = 1;
        while (ind < args.len) {
            const arg: [:0]u8 = args[ind];

            var offset: usize = 0;
            if (std.mem.startsWith(u8, arg, "--")) {
                offset = 2;
            } else if (std.mem.startsWith(u8, arg, "-")) {
                offset = 1;
            }

            if (offset == 0) {
                var arg_dupe: []const u8 = allocator.dupe(u8, arg) catch unreachable;
                map.put("", arg_dupe) catch unreachable;
                ind += 1;
                continue;
            }

            if (ind + 1 < args.len) {
                var arg_dupe: []const u8 = allocator.dupe(u8, arg[offset..]) catch unreachable;
                var val_dupe: []const u8 = allocator.dupe(u8, args[ind + 1]) catch unreachable;
                map.put(arg_dupe, val_dupe) catch unreachable;
                ind += 2;
            }
        }

        return map;
    }

    pub fn initSystems(self: *Application) !void {
        try Global.config.load();

        if (c.glfwInit() == c.GLFW_FALSE) {
            printError("GLFW", "Couldn't initialize GLFW");
            return error.GLFW_FAILED_TO_INIT;
        }
        errdefer c.glfwTerminate();

        _ = c.glfwSetErrorCallback(glfwErrorCallback);

        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        c.glfwWindowHint(c.GLFW_MAXIMIZED, c.GLFW_TRUE);
        self.window = c.glfwCreateWindow(640, 480, @ptrCast([*c]const u8, self.name), null, null) orelse {
            printError("GLFW", "Couldn't create window");
            return error.GLFW_FAILED_TO_CREATE_WINDOW;
        };
        errdefer c.glfwDestroyWindow(self.window);

        try application_glfw_map.putNoClobber(self.window, self);

        c.glfwSetInputMode(self.window, c.GLFW_STICKY_KEYS, c.GLFW_TRUE);

        _ = c.glfwSetKeyCallback(self.window, glfwKeyCallback);
        _ = c.glfwSetCharCallback(self.window, glfwCharCallback);
        _ = c.glfwSetScrollCallback(self.window, glfwScrollCallback);
        _ = c.glfwSetMouseButtonCallback(self.window, glfwMouseButtonCallback);

        if (c.glfwVulkanSupported() == c.GLFW_FALSE) {
            printError("GLFW", "Vulkan is not supported");
            return error.GLFW_VULKAN_NOT_SUPPORTED;
        }

        for (self.systems) |system|
            system.init(system, self);

        rg.global_render_graph.initPasses();

        glfwInitKeymap();

        _ = c.glfwSetFramebufferSizeCallback(self.window, framebufferResizeCallback);
    }

    pub fn deinitSystems(self: *Application) void {
        rg.global_render_graph.deinitCommandBuffers();

        var i: usize = self.systems.len - 1;
        while (i > 0) : (i -= 1) {
            self.systems[i].deinit(self.systems[i]);
        }

        Global.config.flush() catch {
            printErrorNoPanic("Config", "Error during config flushing");
        };

        _ = application_glfw_map.remove(self.window);

        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();
        Global.config.deinit();
    }

    pub fn close(self: *Application) void {
        c.glfwSetWindowShouldClose(self.window, 1);
    }

    pub fn mainLoop(self: *Application) !void {
        var prev_time: f64 = c.glfwGetTime();

        var tracy_frame: tracy.Frame = undefined;

        while (c.glfwWindowShouldClose(self.window) == c.GLFW_FALSE) {
            if (nyancore_options.enable_tracing)
                tracy_frame = tracy.Frame.start(null);

            c.glfwPollEvents();

            self.updateMousePosAndButtons();

            const now_time = c.glfwGetTime();
            const elapsed = now_time - prev_time;
            prev_time = now_time;

            const io: *c.ImGuiIO = c.igGetIO();
            io.DeltaTime = @floatCast(f32, elapsed);

            self.updateDelayedTasks(elapsed);

            for (self.systems) |system|
                system.update(system, elapsed);

            self.framebuffer_resized = false;

            if (nyancore_options.enable_tracing)
                tracy_frame.end();
        }
    }

    fn framebufferResizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
        _ = width;
        _ = height;

        var self: *Application = application_glfw_map.get(window.?).?;
        self.framebuffer_resized = true;
    }

    fn glfwMouseButtonCallback(window: ?*c.GLFWwindow, button: c_int, action: c_int, mods: c_int) callconv(.C) void {
        _ = mods;

        var self: *Application = application_glfw_map.get(window.?).?;
        if (action == c.GLFW_PRESS and button >= 0 and button < imgui_mouse_button_count)
            self.mouse_just_pressed[@intCast(usize, button)] = true;
    }

    fn updateDelayedTasks(self: *Application, elapsed: f64) void {
        var i: usize = 0;
        while (i < self.delayed_tasks.items.len) {
            const t: *DelayedTask = &self.delayed_tasks.items[i];
            t.delay -= elapsed;
            if (t.delay <= 0.0) {
                t.task(t.context);
                _ = self.delayed_tasks.swapRemove(i);
                continue;
            }
            i += 1;
        }
    }

    fn updateMousePosAndButtons(self: *Application) void {
        var io: *c.ImGuiIO = c.igGetIO();

        var i: usize = 0;
        while (i < imgui_mouse_button_count) : (i += 1) {
            io.MouseDown[i] = self.mouse_just_pressed[i] or (c.glfwGetMouseButton(self.window, @intCast(c_int, i)) == c.GLFW_TRUE);
            self.mouse_just_pressed[i] = false;
        }

        const mouse_pos_backup: c.ImVec2 = io.MousePos;
        io.MousePos = .{
            .x = -c.igGET_FLT_MAX(),
            .y = -c.igGET_FLT_MAX(),
        };

        const focused: bool = c.glfwGetWindowAttrib(self.window, c.GLFW_FOCUSED) == c.GLFW_TRUE;
        if (focused) {
            if (io.WantSetMousePos) {
                c.glfwSetCursorPos(self.window, @floatCast(f64, mouse_pos_backup.x), @floatCast(f64, mouse_pos_backup.y));
            } else {
                var mouseX: f64 = undefined;
                var mouseY: f64 = undefined;
                c.glfwGetCursorPos(self.window, &mouseX, &mouseY);
                io.MousePos = .{
                    .x = @floatCast(f32, mouseX),
                    .y = @floatCast(f32, mouseY),
                };
            }
        }
    }

    fn glfwInitKeymap() void {
        var io: *c.ImGuiIO = c.igGetIO();

        io.KeyMap[c.ImGuiKey_Tab] = c.GLFW_KEY_TAB;
        io.KeyMap[c.ImGuiKey_LeftArrow] = c.GLFW_KEY_LEFT;
        io.KeyMap[c.ImGuiKey_RightArrow] = c.GLFW_KEY_RIGHT;
        io.KeyMap[c.ImGuiKey_UpArrow] = c.GLFW_KEY_UP;
        io.KeyMap[c.ImGuiKey_DownArrow] = c.GLFW_KEY_DOWN;
        io.KeyMap[c.ImGuiKey_PageUp] = c.GLFW_KEY_PAGE_UP;
        io.KeyMap[c.ImGuiKey_PageDown] = c.GLFW_KEY_PAGE_DOWN;
        io.KeyMap[c.ImGuiKey_Home] = c.GLFW_KEY_HOME;
        io.KeyMap[c.ImGuiKey_End] = c.GLFW_KEY_END;
        io.KeyMap[c.ImGuiKey_Insert] = c.GLFW_KEY_INSERT;
        io.KeyMap[c.ImGuiKey_Delete] = c.GLFW_KEY_DELETE;
        io.KeyMap[c.ImGuiKey_Backspace] = c.GLFW_KEY_BACKSPACE;
        io.KeyMap[c.ImGuiKey_Space] = c.GLFW_KEY_SPACE;
        io.KeyMap[c.ImGuiKey_Enter] = c.GLFW_KEY_ENTER;
        io.KeyMap[c.ImGuiKey_Escape] = c.GLFW_KEY_ESCAPE;
        io.KeyMap[c.ImGuiKey_KeyPadEnter] = c.GLFW_KEY_KP_ENTER;
        io.KeyMap[c.ImGuiKey_A] = c.GLFW_KEY_A;
        io.KeyMap[c.ImGuiKey_C] = c.GLFW_KEY_C;
        io.KeyMap[c.ImGuiKey_V] = c.GLFW_KEY_V;
        io.KeyMap[c.ImGuiKey_X] = c.GLFW_KEY_X;
        io.KeyMap[c.ImGuiKey_Y] = c.GLFW_KEY_Y;
        io.KeyMap[c.ImGuiKey_Z] = c.GLFW_KEY_Z;
    }

    fn glfwErrorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
        _ = err;

        printError("GLFW", std.mem.span(description));
    }

    fn glfwKeyCallback(win: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
        _ = win;
        _ = scancode;
        _ = mods;

        var io: *c.ImGuiIO = c.igGetIO();

        if (action == c.GLFW_PRESS)
            io.KeysDown[@intCast(c_uint, key)] = true;
        if (action == c.GLFW_RELEASE)
            io.KeysDown[@intCast(c_uint, key)] = false;

        // Modifiers are not reliable across systems
        io.KeyCtrl = io.KeysDown[c.GLFW_KEY_LEFT_CONTROL] or io.KeysDown[c.GLFW_KEY_RIGHT_CONTROL];
        io.KeyShift = io.KeysDown[c.GLFW_KEY_LEFT_SHIFT] or io.KeysDown[c.GLFW_KEY_RIGHT_SHIFT];
        io.KeyAlt = io.KeysDown[c.GLFW_KEY_LEFT_ALT] or io.KeysDown[c.GLFW_KEY_RIGHT_ALT];
        if (builtin.os.tag == .windows) {
            io.KeySuper = false;
        } else {
            io.KeySuper = io.KeysDown[c.GLFW_KEY_LEFT_SUPER] or io.KeysDown[c.GLFW_KEY_RIGHT_SUPER];
        }
    }

    fn glfwCharCallback(win: ?*c.GLFWwindow, char: c_uint) callconv(.C) void {
        _ = win;

        var io: *c.ImGuiIO = c.igGetIO();
        c.ImGuiIO_AddInputCharacter(io, char);
    }

    fn glfwScrollCallback(win: ?*c.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.C) void {
        _ = win;
        var io: *c.ImGuiIO = c.igGetIO();
        io.MouseWheelH += @floatCast(f32, xoffset);
        io.MouseWheel += @floatCast(f32, yoffset);
    }

    pub fn set_icon(self: *Application, data: []const u8) void {
        var buffer_stream: std.io.FixedBufferStream([]const u8) = undefined;
        buffer_stream.buffer = data;
        buffer_stream.pos = 0;

        const images: []Image = ico.parse(buffer_stream.reader(), self.allocator) catch unreachable;
        defer self.allocator.free(images);

        const glfw_images: []c.GLFWimage = self.allocator.alloc(c.GLFWimage, images.len) catch unreachable;
        defer self.allocator.free(glfw_images);

        for (glfw_images) |*img, i|
            img.* = images[i].asGLFWimage();

        c.glfwSetWindowIcon(self.window, @intCast(c_int, images.len), glfw_images.ptr);

        for (images) |img|
            self.allocator.free(img.data);
    }
};
