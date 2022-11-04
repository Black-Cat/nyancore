const std = @import("std");

const Image = @import("image.zig").Image;
const printError = @import("../application/print_error.zig").printError;

const ImageHeader = struct {
    size: i32,
    width: i32,
    height: i32,

    planes: i16,
    bit_count: i16,

    compression: i32,
    size_image: i32,
    xpels_per_meter: i32,
    ypels_per_meter: i32,
    clr_used: i32,
    clr_important: i32,

    pub fn read(reader: anytype) !ImageHeader {
        var header: ImageHeader = undefined;

        header.size = try reader.readIntLittle(i32);
        header.width = try reader.readIntLittle(i32);
        header.height = try reader.readIntLittle(i32);

        header.planes = try reader.readIntLittle(i16);
        header.bit_count = try reader.readIntLittle(i16);

        header.compression = try reader.readIntLittle(i32);
        header.size_image = try reader.readIntLittle(i32);
        header.xpels_per_meter = try reader.readIntLittle(i32);
        header.ypels_per_meter = try reader.readIntLittle(i32);
        header.clr_used = try reader.readIntLittle(i32);
        header.clr_important = try reader.readIntLittle(i32);

        return header;
    }

    pub fn write(self: *const ImageHeader, writer: anytype) !void {
        try writer.writeIntLittle(i32, self.size);
        try writer.writeIntLittle(i32, self.width);
        try writer.writeIntLittle(i32, self.height);

        try writer.writeIntLittle(i16, self.planes);
        try writer.writeIntLittle(i16, self.bit_count);

        try writer.writeIntLittle(i32, self.compression);
        try writer.writeIntLittle(i32, self.size_image);
        try writer.writeIntLittle(i32, self.xpels_per_meter);
        try writer.writeIntLittle(i32, self.ypels_per_meter);
        try writer.writeIntLittle(i32, self.clr_used);
        try writer.writeIntLittle(i32, self.clr_important);
    }
};

pub fn check_header(reader: anytype) !bool {
    const bmp_signature = [_]u8{ "B", "M" };
    const has_header: bool = try reader.isBytes(&bmp_signature);
    try reader.skipByes(4 + 2 + 2 + 4);
    return has_header;
}

// Without header
// Use check_header to read and check bmp file signature
pub fn parse(reader: anytype, allocator: std.mem.Allocator) !Image {
    // Assumes basic 40-byte Windows Image Header
    var image_header: ImageHeader = try ImageHeader.read(reader);

    const flip: bool = image_header.height >= 0;

    // Bmp from ico have height multiplyed by 2. Recalc height from image size
    image_header.height = @divExact(image_header.size_image, image_header.width * 4);

    var image: Image = undefined;
    image.width = @intCast(usize, image_header.width);
    image.height = @intCast(usize, image_header.height);
    image.data = allocator.alloc(u8, image.width * image.height * 4) catch unreachable;

    _ = try reader.readAll(image.data);

    if (flip)
        image.flip();

    return image;
}

pub fn write(writer: anytype, image: Image) !void {
    // File Header (14 Bytes)
    try writer.writeAll("BM"); // type
    try writer.writeIntLittle(u32, 122 + @intCast(u32, image.data.len)); // size
    try writer.writeAll("\x00" ** 4); // reserved
    try writer.writeIntLittle(u32, 122); // offset

    // Image Header (40 Bytes)
    var image_header: ImageHeader = .{
        .size = 108,
        .width = @intCast(i32, image.width),
        .height = -@intCast(i32, image.height),
        .planes = 1,
        .bit_count = 32,
        .compression = 3,
        .size_image = @intCast(i32, image.data.len),
        .xpels_per_meter = 0,
        .ypels_per_meter = 0,
        .clr_used = 0,
        .clr_important = 0,
    };
    try image_header.write(writer);

    // Color Table (68 Bytes)
    try writer.writeAll("\xFF\x00\x00\x00"); // Red
    try writer.writeAll("\x00\xFF\x00\x00"); // Green
    try writer.writeAll("\x00\x00\xFF\x00"); // Blue
    try writer.writeAll("\x00\x00\x00\xFF"); // Alpha
    try writer.writeAll("\x20\x6E\x69\x57"); // "Win "
    try writer.writeAll("\x00" ** 48);

    // Pixel Data
    try writer.writeAll(image.data);
}
