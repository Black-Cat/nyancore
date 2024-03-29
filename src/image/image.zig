const std = @import("std");

const c = @import("../c.zig");

pub const Image = struct {
    width: usize,
    height: usize,

    data: []u8, // RGBA 32bit

    pub fn clone(self: *Image, allocator: std.mem.Allocator) Image {
        return .{
            .width = self.width,
            .height = self.height,
            .data = allocator.dupe(u8, self.data) catch unreachable,
        };
    }

    pub fn asGLFWimage(self: *Image) c.GLFWimage {
        return .{
            .width = @intCast(self.width),
            .height = @intCast(self.height),
            .pixels = @ptrCast(self.data.ptr),
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

                const r: f64 = (@as(f64, @floatFromInt(val[2])) - 128.0) * 1.402 + @as(f64, @floatFromInt(val[0]));
                const b: f64 = (@as(f64, @floatFromInt(val[1])) - 128.0) * 1.772 + @as(f64, @floatFromInt(val[0]));
                const g: f64 = @as(f64, @floatFromInt(val[0])) - 0.344136 * (@as(f64, @floatFromInt(val[1])) - 128.0) - 0.714136 * (@as(f64, @floatFromInt(val[2])) - 128.0);

                val[0] = @intFromFloat(std.math.clamp(r, 0.0, 255.0));
                val[1] = @intFromFloat(std.math.clamp(g, 0.0, 255.0));
                val[2] = @intFromFloat(std.math.clamp(b, 0.0, 255.0));
            }
        }
    }
};
