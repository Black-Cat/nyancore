const std = @import("std");

const Image = @import("image.zig").Image;
const printError = @import("../application/print_error.zig").printError;

const Chunk = struct {
    length: u32,
    chunk_type: [4]u8,
    chunk_data: []u8,
    crc: u32,

    pub fn read(reader: anytype, allocator: std.mem.Allocator) !Chunk {
        var chunk: Chunk = undefined;
        chunk.length = try reader.readIntBig(u32);
        _ = try reader.readAll(chunk.chunk_type[0..]);
        chunk.chunk_data = allocator.alloc(u8, chunk.length) catch unreachable;
        _ = try reader.readAll(chunk.chunk_data);
        chunk.crc = try reader.readIntBig(u32);
        return chunk;
    }
};

const IHDRImageHeader = struct {
    width: i32,
    height: i32,
    bit_depth: u8,
    color_type: u8,
    compression_method: u8,
    filter_method: u8,
    interlace_method: u8,

    pub fn read(reader: anytype) !IHDRImageHeader {
        var header: IHDRImageHeader = undefined;
        header.width = try reader.readIntBig(i32);
        header.height = try reader.readIntBig(i32);
        header.bit_depth = try reader.readByte();
        header.color_type = try reader.readByte();
        header.compression_method = try reader.readByte();
        header.filter_method = try reader.readByte();
        header.interlace_method = try reader.readByte();
        return header;
    }
};

pub fn check_header(reader: anytype) !bool {
    const png_signature = [_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };
    return try reader.isBytes(&png_signature);
}

// Without header
// Use check_header to read and check png file signature
pub fn parse(reader: anytype, allocator: std.mem.Allocator) !Image {
    var ihdr_chunk: Chunk = try Chunk.read(reader, allocator);
    defer allocator.free(ihdr_chunk.chunk_data);

    var fbs: std.io.FixedBufferStream([]const u8) = undefined;
    fbs.buffer = ihdr_chunk.chunk_data;
    fbs.pos = 0;
    const image_header: IHDRImageHeader = try IHDRImageHeader.read(fbs.reader());

    var image: Image = undefined;
    image.width = @intCast(usize, image_header.width);
    image.height = @intCast(usize, image_header.height);
    image.data = allocator.alloc(u8, image.width * image.height * 4) catch unreachable;

    while (true) {
        var chunk: Chunk = Chunk.read(reader, allocator) catch break;
        defer allocator.free(chunk.chunk_data);

        if (std.mem.eql(u8, chunk.chunk_type[0..], "IEND"))
            break;

        if (std.mem.eql(u8, chunk.chunk_type[0..], "IDAT")) {
            var data_stream = std.io.fixedBufferStream(chunk.chunk_data);
            var zlib_stream = try std.compress.zlib.zlibStream(allocator, data_stream.reader());
            defer zlib_stream.deinit();

            var deflated_data = try zlib_stream.reader().readAllAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(deflated_data);

            const scanline_size: usize = image.width * 4 + 1;

            const bpp: usize = 4;

            var y: usize = 0;
            while (y < image.height) : (y += 1) {
                const filter: u8 = deflated_data[y * scanline_size];
                var scanline: []const u8 = deflated_data[y * scanline_size + 1 .. (y + 1) * scanline_size];

                switch (filter) {
                    0 => { // None
                        std.mem.copy(u8, image.data[y * image.width * 4 ..], scanline);
                    },
                    1 => { // Sub
                        for (scanline) |_, x| {
                            const prev: u8 = if (x - bpp < 0) 0 else image.data[y * image.width * 4 + x - bpp];
                            image.data[y * image.width * 4 + x] = scanline[x] +% prev;
                        }
                    },
                    2 => { // Up
                        for (scanline) |_, x| {
                            const prev: u8 = if (y == 0) 0 else image.data[(y - 1) * image.width * 4 + x];
                            image.data[y * image.width * 4 + x] = scanline[x] +% prev;
                        }
                    },
                    3 => { // Average
                        for (scanline) |_, x| {
                            const prev: i32 = if (y == 0) 0 else @intCast(i32, image.data[(y - 1) * image.width * 4 + x]);
                            const prev_x: i32 = if (x - bpp < 0) 0 else @intCast(i32, image.data[y * image.width * 4 + x - bpp]);
                            image.data[y * image.width * 4 + x] = @intCast(u8, @mod(@intCast(i32, scanline[x]) + @divFloor(prev_x + prev, 2), 256));
                        }
                    },
                    4 => { // Paeth
                        for (scanline) |_, x| {
                            const prev_y: u8 = if (y == 0) 0 else image.data[(y - 1) * image.width * 4 + x];
                            const prev_x: u8 = if (x - bpp < 0) 0 else image.data[y * image.width * 4 + x - bpp];
                            const prev_x_y: u8 = if (x - bpp < 0 or y == 0) 0 else image.data[(y - 1) * image.width * 4 + x - bpp];
                            image.data[y * image.width * 4 + x] = scanline[x] +% paethPredictor(prev_x, prev_y, prev_x_y);
                        }
                    },
                    else => {
                        printError("PNG", "Unknown png filter");
                    },
                }
            }
        }
    }

    return image;
}

fn paethPredictor(left: u8, above: u8, upper_left: u8) u8 {
    const initial_estimate: i32 = @intCast(i32, left) + @intCast(i32, above) - @intCast(i32, upper_left);

    const distance_left: i32 = std.math.absInt(initial_estimate - left) catch unreachable;
    const distance_above: i32 = std.math.absInt(initial_estimate - above) catch unreachable;
    const distance_upper_left: i32 = std.math.absInt(initial_estimate - upper_left) catch unreachable;

    // return nearest
    // breaking ties in order: left, above, upper left
    if (distance_left <= distance_above and distance_left <= distance_upper_left) {
        return left;
    } else {
        return if (distance_above <= distance_upper_left) above else upper_left;
    }
}
