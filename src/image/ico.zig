const std = @import("std");

const bmp = @import("bmp.zig");
const png = @import("png.zig");

const Image = @import("image.zig").Image;

const IcoHeader = struct {
    reserved: u16,
    image_type: u16,
    image_count: u16,

    pub fn read(reader: anytype) !IcoHeader {
        var ico_header: IcoHeader = undefined;
        ico_header.reserved = try reader.readIntLittle(u16);
        ico_header.image_type = try reader.readIntLittle(u16);
        ico_header.image_count = try reader.readIntLittle(u16);
        return ico_header;
    }
};

const IcoDirEntry = struct {
    width: u8,
    height: u8,
    colpaletter: u8,
    reserved: u8,

    planes: u16,
    bpp: u16,

    size: u32,
    offset: u32,

    pub fn read(reader: anytype) !IcoDirEntry {
        var ico_dir_entry: IcoDirEntry = undefined;
        ico_dir_entry.width = try reader.readIntLittle(u8);
        ico_dir_entry.height = try reader.readIntLittle(u8);
        ico_dir_entry.colpaletter = try reader.readIntLittle(u8);
        ico_dir_entry.reserved = try reader.readIntLittle(u8);

        ico_dir_entry.planes = try reader.readIntLittle(u16);
        ico_dir_entry.bpp = try reader.readIntLittle(u16);

        ico_dir_entry.size = try reader.readIntLittle(u32);
        ico_dir_entry.offset = try reader.readIntLittle(u32);
        return ico_dir_entry;
    }
};

pub fn parse(reader: anytype, allocator: std.mem.Allocator) ![]Image {
    const header: IcoHeader = IcoHeader.read(reader) catch unreachable;

    const icons: []IcoDirEntry = allocator.alloc(IcoDirEntry, header.image_count) catch unreachable;
    defer allocator.free(icons);

    for (icons) |*ico|
        ico.* = IcoDirEntry.read(reader) catch unreachable;

    var seekable_stream = reader.context.seekableStream();

    var images: []Image = allocator.alloc(Image, header.image_count) catch unreachable;
    for (icons, 0..) |ico, i| {
        try seekable_stream.seekTo(ico.offset);
        if (png.check_header(reader) catch false) {
            images[i] = try png.parse(reader, allocator);
        } else {
            seekable_stream.seekTo(ico.offset) catch unreachable;
            images[i] = try bmp.parse(reader, allocator);
        }
    }

    return images;
}
