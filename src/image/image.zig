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

    pub fn ycbcr2rgb(self: *Image) void {
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                const ind: usize = (y * self.width + x) * 4;
                var val: []u8 = self.data[ind .. ind + 4];

                const r: f64 = (@intToFloat(f64, val[2]) - 128.0) * 1.402 + @intToFloat(f64, val[0]);
                const b: f64 = (@intToFloat(f64, val[1]) - 128.0) * 1.772 + @intToFloat(f64, val[0]);
                const g: f64 = @intToFloat(f64, val[0]) - 0.344136 * (@intToFloat(f64, val[1]) - 128.0) - 0.714136 * (@intToFloat(f64, val[2]) - 128.0);

                val[0] = @floatToInt(u8, std.math.clamp(r + 128.0, 0.0, 255.0));
                val[1] = @floatToInt(u8, std.math.clamp(g + 128.0, 0.0, 255.0));
                val[2] = @floatToInt(u8, std.math.clamp(b + 128.0, 0.0, 255.0));
            }
        }
    }
};
