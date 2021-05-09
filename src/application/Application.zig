usingnamespace @import("Config.zig");

const imgui_mouse_button_count = 5;

pub const Application = struct {
    allocator: *Allocator,
    config: Config,
    name: []const u8,
    mouse_just_pressed: [imgui_mouse_button_count]bool,

    pub fn create(name: []const u8, allocator: *Allocator) !*Application {
        const self = try allocator.create(Application);

        self.* = .{
            .allocator = allocator,
            .name = name,
            .mouse_just_pressed = [_]bool{false} ** imgui_mouse_button_count,
        };

        return self;
    }

    pub fn start(self: *Application) void {
        config.init(self.alocator, self.name, self.name + ".conf");
        defer config.deinit();

        config.loadConfig();

        config.flushConfig();
    }

    fn glfwErrorCallback(errorCode: i32, description: []const u8) void {}
};
