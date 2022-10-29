const std = @import("std");

const Image = @import("image.zig").Image;
const printError = @import("../application/print_error.zig").printError;

const print_header = false;

pub fn checkHeader(reader: anytype) !bool {
    const jpg_signature = [_]u8{ 0xFF, 0xD8 };
    return reader.isBytes(&jpg_signature);
}

const zig_zag: [64]u8 = .{
    0,  1,  5,  6,  14, 15, 27, 28,
    2,  4,  7,  13, 16, 26, 29, 42,
    3,  8,  12, 17, 25, 30, 41, 43,
    9,  11, 18, 24, 31, 40, 44, 53,
    10, 19, 23, 32, 39, 45, 52, 54,
    20, 22, 33, 38, 46, 51, 55, 60,
    21, 34, 37, 47, 50, 56, 59, 61,
    35, 36, 48, 49, 57, 58, 62, 63,
};
const dezig_zag: [64]u8 = .{
    0,  1,  8,  16, 9,  2,  3,  10,
    17, 24, 32, 25, 18, 11, 4,  5,
    12, 19, 26, 33, 40, 48, 41, 34,
    27, 20, 13, 6,  7,  14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36,
    29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46,
    53, 60, 61, 54, 47, 55, 62, 63,
};

const HuffmanTable = struct {
    allocator: std.mem.Allocator,

    ht_number: u4,
    ht_type: u1, // 0 = DC, 1 = AC

    length_counts: [16]u8,
    code_lengths: [257]u8,
    codes: [256]u16,

    min_codes: [17]u16,
    max_codes: [18]u16,
    first_codes: [17]usize,

    symbols: []u8,

    pub fn parse(reader: anytype, allocator: std.mem.Allocator) !HuffmanTable {
        var table: HuffmanTable = undefined;
        table.allocator = allocator;

        _ = try reader.readIntBig(u16); // Chunk length

        const ht_information: u8 = try reader.readIntBig(u8);
        table.ht_number = @truncate(u4, ht_information);
        table.ht_type = @truncate(u1, ht_information >> 4);

        _ = try reader.readAll(table.length_counts[0..]);

        var total_symbol_count: usize = 0;
        for (table.length_counts) |sc|
            total_symbol_count += sc;

        table.symbols = allocator.alloc(u8, total_symbol_count) catch unreachable;
        _ = try reader.readAll(table.symbols);

        table.generateCodes();

        return table;
    }

    fn generateCodes(self: *HuffmanTable) void {
        self.code_lengths = [_]u8{0} ** self.code_lengths.len;
        self.codes = [_]u16{0} ** self.codes.len;
        self.max_codes = [_]u16{0} ** self.max_codes.len;
        self.min_codes = [_]u16{0} ** self.min_codes.len;
        self.first_codes = [_]usize{0} ** self.first_codes.len;

        var code_counter: usize = 0;
        for (self.length_counts) |count, ind| {
            var i: usize = 0;
            while (i < count) : (i += 1) {
                self.code_lengths[code_counter] = @intCast(u8, ind) + 1;
                code_counter += 1;
            }
        }
        self.code_lengths[code_counter] = 0;

        code_counter = 0;
        var length_counter: usize = 1;
        var index: usize = 0;
        while (length_counter <= 16) : (length_counter += 1) {
            self.min_codes[length_counter] = @intCast(u16, code_counter);
            self.first_codes[length_counter] = index;
            while (self.code_lengths[index] == length_counter) {
                self.codes[index] = @intCast(u16, code_counter);
                code_counter += 1;
                index += 1;
            }
            self.max_codes[length_counter] = @intCast(u16, code_counter);
            code_counter <<= 1;
        }
        self.max_codes[length_counter] = std.math.maxInt(u16);
    }

    pub fn decode(self: *HuffmanTable, bit_reader: anytype) !u8 {
        var code: usize = 0;
        var code_length: u8 = 0;
        var out_bits: usize = undefined;
        while (code_length <= 16) {
            code <<= 1;
            code |= try bit_reader.readBits(usize, 1, &out_bits);
            code_length += 1;
            if (code < self.max_codes[code_length]) {
                var index: usize = self.first_codes[code_length] + code - self.min_codes[code_length];
                return self.symbols[index];
            }
        }
        unreachable;
    }

    pub fn deinit(self: *HuffmanTable) void {
        self.allocator.free(self.symbols);
    }

    pub fn debugPrint(self: *const HuffmanTable) void {
        std.debug.print("Huffman Table {d}:\n", .{self.ht_number});
        std.debug.print("\t{d}\n", .{self.length_counts[0..8].*});
        std.debug.print("\t{d}\n", .{self.length_counts[8..16].*});
    }
};

const QuantizationTable = struct {
    number: u4,
    precision: u4,
    values: []u8,

    allocator: std.mem.Allocator,

    pub fn parse(reader: anytype, allocator: std.mem.Allocator) !QuantizationTable {
        var table: QuantizationTable = undefined;
        table.allocator = allocator;

        _ = try reader.readIntBig(u16); // Chunk length

        const qt_information: u8 = try reader.readIntBig(u8);
        table.number = @truncate(u4, qt_information);
        table.precision = @truncate(u4, qt_information >> 4);

        const buffer_size: usize = 64 * @intCast(usize, (table.precision + 1));
        table.values = allocator.alloc(u8, buffer_size) catch unreachable;

        var temp_buffer: []u8 = allocator.alloc(u8, buffer_size) catch unreachable;
        defer allocator.free(temp_buffer);
        _ = try reader.readAll(temp_buffer);

        for (table.values) |*v, ind|
            v.* = temp_buffer[zig_zag[ind]];

        return table;
    }

    pub fn deinit(self: *QuantizationTable) void {
        self.allocator.free(self.values);
    }

    pub fn debugPrint(self: *const QuantizationTable) void {
        std.debug.print("Quantization Table:\n\tNumber: {d}, Precision: {d}\n", .{
            self.number,
            self.precision,
        });

        var row: usize = 0;
        for (self.values) |v| {
            std.debug.print("\t{d}", .{v});
            row += 1;
            if (row >= 8) {
                row = 0;
                std.debug.print("\n", .{});
            }
        }
        if (row != 0)
            std.debug.print("\n", .{});
    }
};

const Frame = struct {
    pub const ComponentData = struct {
        id: u8,
        sampling_factor_vertical: u4,
        sampling_factor_horizontal: u4,
        quantization_table: u8,
    };

    allocator: std.mem.Allocator,

    precision: u8,
    height: u16,
    width: u16,
    components_count: u8,
    components: []ComponentData,

    pub fn parse(reader: anytype, allocator: std.mem.Allocator) !Frame {
        var frame: Frame = undefined;
        frame.allocator = allocator;

        _ = try reader.readIntBig(u16); // Chunk length

        frame.precision = try reader.readIntBig(u8);
        frame.height = try reader.readIntBig(u16);
        frame.width = try reader.readIntBig(u16);
        frame.components_count = try reader.readIntBig(u8);

        frame.components = allocator.alloc(ComponentData, frame.components_count) catch unreachable;
        for (frame.components) |*c| {
            c.id = try reader.readIntBig(u8);
            const sampling_factors: u8 = try reader.readIntBig(u8);
            c.sampling_factor_vertical = @truncate(u4, sampling_factors);
            c.sampling_factor_horizontal = @truncate(u4, sampling_factors >> 4);
            c.quantization_table = try reader.readIntBig(u8);
        }

        return frame;
    }

    pub fn deinit(self: *Frame) void {
        self.allocator.free(self.components);
    }

    pub fn debugPrint(self: *Frame) void {
        std.debug.print("Frame: Width={d} Height={d} Components={d}\n", .{ self.height, self.width, self.components_count });
        for (self.components) |c, ind|
            std.debug.print("\t[{d}]: {d}h x {d}v, q={d}\n", .{
                ind,
                c.sampling_factor_horizontal,
                c.sampling_factor_vertical,
                c.quantization_table,
            });
    }
};

const ScanData = struct {
    pub const ComponentDescriptor = struct {
        dc: u4,
        ac: u4,
    };

    allocator: std.mem.Allocator,

    components: u8,
    component_descriptors: []ComponentDescriptor,
    spectral_select: [2]u8,
    successive_approx: [2]u4,

    data: []u8,

    pub fn parse(reader: anytype, allocator: std.mem.Allocator) !ScanData {
        var scan: ScanData = undefined;
        scan.allocator = allocator;

        _ = try reader.readIntBig(u16); // Chunk length

        scan.components = try reader.readIntBig(u8);
        scan.component_descriptors = allocator.alloc(ComponentDescriptor, scan.components) catch unreachable;
        for (scan.component_descriptors) |_| {
            const index: u8 = try reader.readIntBig(u8);
            const selector_data: u8 = try reader.readIntBig(u8);
            scan.component_descriptors[index - 1].ac = @truncate(u4, selector_data);
            scan.component_descriptors[index - 1].dc = @truncate(u4, selector_data >> 4);
        }

        _ = try reader.readAll(scan.spectral_select[0..]);
        var temp: u8 = try reader.readIntBig(u8);
        scan.successive_approx[0] = @truncate(u4, temp);
        scan.successive_approx[1] = @truncate(u4, temp >> 4);

        var data_array_list = std.ArrayList(u8).init(allocator);
        defer data_array_list.deinit();

        while (true) {
            const b: u8 = try reader.readByte();
            if (b == 0xFF) {
                const next_b: u8 = try reader.readByte();
                if (next_b == 0xD9)
                    break;
            }

            data_array_list.append(b) catch unreachable;
        }

        scan.data = data_array_list.toOwnedSlice();

        return scan;
    }

    pub fn deinit(self: *ScanData) void {
        self.allocator.free(self.component_descriptors);
        self.allocator.free(self.data);
    }

    pub fn debugPrint(self: *ScanData) void {
        std.debug.print("Scan:\n", .{});
        for (self.component_descriptors) |c, ind|
            std.debug.print("\tComponent {d}: dc={d} ac={d}\n", .{ ind, c.dc, c.ac });
        std.debug.print("\tSs={d} Se={d} Ah={d} Al={d}\n", .{
            self.spectral_select[0],
            self.spectral_select[1],
            self.successive_approx[0],
            self.successive_approx[1],
        });
    }
};

// Without header
pub fn parse(reader: anytype, allocator: std.mem.Allocator) !Image {
    var huffman_tables: [4]HuffmanTable = undefined;
    defer for (huffman_tables) |*ht| ht.deinit();

    var quantization_tables: [2]QuantizationTable = undefined;
    defer for (quantization_tables) |*qt| qt.deinit();

    var frame: Frame = undefined;
    defer frame.deinit();

    var scan_data: ScanData = undefined;
    defer scan_data.deinit();

    var marker: u16 = undefined;
    var chunk_length: u16 = undefined;

    while (true) {
        marker = try reader.readIntBig(u16);

        switch (marker) {
            0xFFDA => {
                scan_data = try ScanData.parse(reader, allocator);
                break;
            },
            0xFFC4 => {
                const table: HuffmanTable = try HuffmanTable.parse(reader, allocator);
                const ind: usize = @as(usize, if (table.ht_type == 0) 0 else 2) + table.ht_number;
                huffman_tables[ind] = table;
            },
            0xFFDB => {
                const table: QuantizationTable = try QuantizationTable.parse(reader, allocator);
                quantization_tables[table.number] = table;
            },
            0xFFC0 => {
                frame = try Frame.parse(reader, allocator);
            },
            else => {
                chunk_length = try reader.readIntBig(u16);
                try reader.skipBytes(chunk_length - 2, .{});
            },
        }
    }

    if (print_header) {
        for (quantization_tables) |qt|
            qt.debugPrint();

        frame.debugPrint();

        for (huffman_tables) |ht|
            ht.debugPrint();

        scan_data.debugPrint();
    }

    var comp_max_h: u4 = 1;
    var comp_max_v: u4 = 1;
    for (frame.components) |c| {
        comp_max_h = @maximum(comp_max_h, c.sampling_factor_horizontal);
        comp_max_v = @maximum(comp_max_v, c.sampling_factor_vertical);
    }

    const mcu_w: usize = @intCast(usize, comp_max_h) * 8;
    const mcu_h: usize = @intCast(usize, comp_max_v) * 8;

    const mcu_x: usize = (frame.width + mcu_w - 1) / mcu_w;
    const mcu_y: usize = (frame.height + mcu_h - 1) / mcu_h;

    var data_stream = std.io.fixedBufferStream(scan_data.data);
    var bit_reader = std.io.bitReader(.Big, data_stream.reader());

    var dcs: []i32 = allocator.alloc(i32, frame.components.len) catch unreachable;
    defer allocator.free(dcs);
    std.mem.set(i32, dcs, 0);

    var image: Image = undefined;
    image.width = frame.width;
    image.height = frame.height;
    image.data = allocator.alloc(u8, image.width * image.height * 4) catch unreachable;

    var mcu_index: usize = 0;
    while (mcu_index < mcu_x * mcu_y) : (mcu_index += 1) {
        for (frame.components) |c, c_ind| {
            const image_pos: usize = (mcu_index / mcu_x) * image.width * 4 * 8 + mcu_index % mcu_x * 4 * 8 + c_ind;

            const descriptor: ScanData.ComponentDescriptor = scan_data.component_descriptors[c_ind];
            const dc_huffman: *HuffmanTable = &huffman_tables[descriptor.dc];
            const ac_huffman: *HuffmanTable = &huffman_tables[2 + descriptor.ac];
            const quant: *QuantizationTable = &quantization_tables[c.quantization_table];
            var cur_dc: *i32 = &dcs[c_ind];

            var i: usize = 0;
            while (i < c.sampling_factor_vertical) : (i += 1) {
                var j: usize = 0;
                while (j < c.sampling_factor_horizontal) : (j += 1) {
                    var block: [64]i32 = try decodeBlock(&bit_reader, dc_huffman, ac_huffman, quant, cur_dc);
                    IDCT.perform(
                        image.data[image_pos..],
                        .{ 4, image.width * 4 },
                        .{ comp_max_h / c.sampling_factor_horizontal, comp_max_v / c.sampling_factor_vertical },
                        block,
                    );
                }
            }
        }
    }

    image.ycbcr2rgb();

    return image;
}

fn decodeBlock(
    bit_reader: anytype,
    dc_huffman: *HuffmanTable,
    ac_huffman: *HuffmanTable,
    quant: *QuantizationTable,
    dc: *i32,
) ![64]i32 {
    dc.* = try decodeDC(bit_reader, dc.*, dc_huffman);
    return try decodeAC(bit_reader, dc.*, ac_huffman, quant);
}

fn extend(additional: u32, magnitude: u8) i32 {
    const l = @as(i32, 1) << (@intCast(u5, magnitude) - 1);
    return if (additional >= l) @intCast(i32, additional) else @intCast(i32, additional) + (@as(i32, -1) << @intCast(u5, magnitude)) + 1;
}

fn decodeDC(bit_reader: anytype, last_dc: i32, dc_huffman: *HuffmanTable) !i32 {
    var code: u8 = try dc_huffman.decode(bit_reader);

    var unused: usize = undefined;
    var bits: u32 = try bit_reader.readBits(u32, code, &unused);

    var difference: i32 = if (code != 0) extend(bits, code) else 0;
    return difference + last_dc;
}

fn decodeAC(bit_reader: anytype, dc: i32, ac_huffman: *HuffmanTable, quant: *QuantizationTable) ![64]i32 {
    var unused: usize = undefined;

    var coeficents: [64]i32 = [_]i32{0} ** 64;
    coeficents[0] = dc * quant.values[0];

    var ii: usize = 1;
    while (ii <= 63) {
        const val: u8 = try ac_huffman.decode(bit_reader);
        const low_bits: u4 = @truncate(u4, val);
        const high_bits: u4 = @truncate(u4, val >> 4);

        if (low_bits != 0) {
            const extra_bits: u32 = try bit_reader.readBits(u32, low_bits, &unused);
            ii += high_bits;
            var zig: usize = dezig_zag[ii];
            coeficents[zig] = extend(extra_bits, low_bits) * quant.values[zig];
            ii += 1;
        } else {
            if (high_bits == 0xF) {
                ii += 16;
            } else if (high_bits == 0) {
                ii = 64; // All done
            }
        }
    }

    return coeficents;
}

// Inverse Discrete Cosine Transformation
const IDCT = struct {
    const precision = 8;
    const coeffs: [64]f64 = generateCoeffs();

    fn generateCoeffs() [64]f64 {
        var temp: [64]f64 = undefined;
        for (temp) |*c, ind| {
            const x: usize = ind % 8;
            const y: usize = ind / 8;
            c.* = normScaleFactor(x) * normScaleFactor(y);
        }
        return temp;
    }

    fn normScaleFactor(u: usize) f32 {
        return if (u == 0) 1.0 / @sqrt(2.0) else 1.0;
    }

    pub fn perform(out: []u8, stride: [2]usize, sampling: [2]usize, data: [64]i32) void {
        var x: usize = 0;
        while (x < 8) : (x += 1) {
            var y: usize = 0;
            while (y < 8) : (y += 1) {
                var local_sum: f64 = 0;
                var u: usize = 0;
                while (u < 8) : (u += 1) {
                    var v: usize = 0;
                    while (v < 8) : (v += 1) {
                        var val: f64 = coeffs[u + v * 8] * @intToFloat(f64, data[u + v * 8]);
                        val *= @cos(@intToFloat(f64, (2 * x + 1) * u) * std.math.pi / 16);
                        val *= @cos(@intToFloat(f64, (2 * y + 1) * v) * std.math.pi / 16);
                        local_sum += val;
                    }
                }

                const val: u8 = @floatToInt(u8, std.math.clamp((local_sum / 4.0) + 128.0, 0.0, 255.0));
                var s_h: usize = 0;
                while (s_h < sampling[0]) : (s_h += 1) {
                    var s_v: usize = 0;
                    while (s_v < sampling[1]) : (s_v += 1)
                        out[((x * sampling[0]) + s_h) * stride[0] + ((y * sampling[1]) + s_v) * stride[1]] = val;
                }
            }
        }
    }
};
