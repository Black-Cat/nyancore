const std = @import("std");

const RGPass = @import("render_graph_pass.zig").RGPass;

const PassList = std.ArrayList(*RGPass);

pub const RGResource = struct {
    const OnChangeCallback = struct {
        pass: *RGPass,
        callback: fn (*RGPass) void,
    };

    name: []const u8,

    writers: PassList,
    readers: PassList,

    pub fn init(self: *RGResource, name: []const u8, allocator: std.mem.Allocator) void {
        self.name = name;

        self.writers = PassList.init(allocator);
        self.readers = PassList.init(allocator);
    }

    pub fn deinit(self: *RGResource) void {
        self.writers.deinit();
        self.readers.deinit();
    }
};
