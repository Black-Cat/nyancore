const c = @import("c.zig");
const std = @import("std");

pub const Frame = struct {
    name: [*c]const u8,

    pub fn mark(name: ?[*c]const u8) void {
        c.___tracy_emit_frame_mark(name);
    }

    pub fn image(image_ptr: ?*const anyopaque, width: u16, height: u16, offset: u8, flip: c_int) void {
        c.___tracy_emit_frame_image(image_ptr, width, height, offset, flip);
    }

    pub fn start(name: ?[*c]const u8) Frame {
        const frame: Frame = .{ .name = if (name) |n| n else null };
        c.___tracy_emit_frame_mark_start(frame.name);
        return frame;
    }

    pub fn end(self: *Frame) void {
        c.___tracy_emit_frame_mark_end(self.name);
    }
};

pub const Zone = struct {
    ctx: c.TracyCZoneCtx,

    pub fn hashColor(comptime str: []const u8) u32 {
        return @truncate(u32, std.hash.Wyhash.hash(0, str));
    }

    pub fn start(comptime src: std.builtin.SourceLocation, name: ?[]const u8, color: u32) Zone {
        var srcloc: u64 = undefined;
        if (name) |n| {
            srcloc = c.___tracy_alloc_srcloc_name(src.line, src.file.ptr, src.file.len, src.fn_name.ptr, src.fn_name.len, n.ptr, n.len);
        } else {
            srcloc = c.___tracy_alloc_srcloc(src.line, src.file.ptr, src.file.len, src.fn_name.ptr, src.fn_name.len);
        }

        var zone: Zone = .{ .ctx = c.___tracy_emit_zone_begin_alloc(srcloc, 1) };
        c.___tracy_emit_zone_color(zone.ctx, color);
        return zone;
    }

    pub fn start_no_color(comptime src: std.builtin.SourceLocation, name: ?[]const u8) Zone {
        return start(src, name, 0);
    }

    pub fn start_color_from_fnc(comptime src: std.builtin.SourceLocation, name: ?[]const u8) Zone {
        return start(src, name, hashColor(src.fn_name));
    }

    pub fn start_color_from_file(comptime src: std.builtin.SourceLocation, name: ?[]const u8) Zone {
        return start(src, name, hashColor(src.file));
    }

    pub fn end(self: *Zone) void {
        _ = self;
        c.___tracy_emit_zone_end(self.ctx);
    }
};
