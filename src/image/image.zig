const std = @import("std");

const c = @import("../c.zig");

pub const Image = struct {
    width: usize,
    height: usize,

    data: []u8, // RGBA 32bit

    pub fn asGLFWimage(self: *Image) c.GLFWimage {
        return .{
            .width = @intCast(c_int, self.width),
            .height = @intCast(c_int, self.height),
            .pixels = @intToPtr([*]u8, @ptrToInt(self.data.ptr)),
        };
    }

    // Flip along horizontal center line
    pub fn flip(self: *Image) void {
        const row_size: usize = self.width * 4;

        var y: usize = 0;
        while (y < @divFloor(self.height, 2)) : (y += 1) {
            var x: usize = 0;
            while (x < row_size) : (x += 1) {
                std.mem.swap(u8, &self.data[y * row_size + x], &self.data[(self.height - 1 - y) * row_size + x]);
            }
        }
    }
};
