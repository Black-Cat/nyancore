const std = @import("std");

pub fn readU32(file: *const std.fs.File) !usize {
    var temp: [@sizeOf(u32)]u8 = undefined;
    _ = try file.readAll(temp[0..]);
    return @intCast(usize, std.mem.readIntBig(u32, &temp));
}

pub fn writeU32(file: *const std.fs.File, val_usize: usize) !void {
    const val_u32: u32 = @intCast(u32, val_usize);
    var temp: [@sizeOf(u32)]u8 = undefined;
    std.mem.writeIntBig(u32, &temp, val_u32);
    try file.writeAll(temp[0..]);
}

pub fn writeU32Little(file: *const std.fs.File, val_usize: usize) !void {
    const val_u32: u32 = @intCast(u32, val_usize);
    var temp: [@sizeOf(u32)]u8 = undefined;
    std.mem.writeIntLittle(u32, &temp, val_u32);
    try file.writeAll(temp[0..]);
}

pub fn writeI32Little(file: *const std.fs.File, val: i32) !void {
    var temp: [@sizeOf(i32)]u8 = undefined;
    std.mem.writeIntLittle(i32, &temp, val);
    try file.writeAll(temp[0..]);
}
