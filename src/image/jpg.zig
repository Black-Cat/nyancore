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

const HuffmanTable = struct {
    allocator: std.mem.Allocator,

    ht_number: u4,
    ht_type: u1, // 0 = DC, 1 = AC

    length_counts: [16]u8,
    code_lengths: [256]u8,
    codes: [255]u16,

    min_codes: [17]u16,
    max_codes: [17]u16,
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
    }

    pub fn decode(self: *HuffmanTable, bit_reader: anytype) !u8 {
        var code: usize = 0;
        var code_length: u8 = 0;
        var out_bits: usize = undefined;
        while (code_length <= 16) {
            code <<= 1;
            code |= try bit_reader.readBits(usize, 1, &out_bits);
            code_length += 1;
            if (code <= self.max_codes[code_length]) {
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

    var mcu_index: usize = 0;
    while (mcu_index < mcu_x * mcu_y) : (mcu_index += 1) {
        for (frame.components) |c| {
            var i: usize = 0;
            while (i < c.sampling_factor_vertical) : (i += 1) {
                var j: usize = 0;
                while (j < c.sampling_factor_vertical) : (j += 1) {
                    _ = bit_reader;
                }
            }
        }
    }

    var image: Image = undefined;
    image.width = 0;
    image.height = 0;
    image.data = allocator.alloc(u8, 100) catch unreachable;

    return image;
}

fn decodeNumber(code: u8, bits: u32) u32 {
    const l = std.math.pow(u32, 2, code - 1);
    return if (bits >= l) bits else bits - (2 * l - 1);
}

fn buildMatrix(
    bit_reader: anytype,
    idx: u32,
    huffman_tables: []HuffmanTable,
    quant: *QuantizationTable,
    coef: *u32,
) ![64]f32 {
    var code: u8 = try huffman_tables[idx].decode(bit_reader);
    var unused: usize = undefined;
    var bits: u32 = try bit_reader.readBits(u32, code, &unused);
    coef.* += decodeNumber(code, bits);

    var mat: [64]u8 = .{0} ** 64;
    mat[0] = @intCast(u8, coef.*) * quant.values[0];

    var l: usize = 1;
    while (l < 64) {
        code = try huffman_tables[2 + idx].decode(bit_reader);
        if (code == 0)
            break;

        if (code > 15) {
            l += code >> 4;
            code &= 0x0F;
        }

        bits = try bit_reader.readBits(u32, code, &unused);

        if (l < 64) {
            var dc_coef = decodeNumber(code, bits);
            mat[l] = @intCast(u8, dc_coef) * quant.values[l];
            l += 1;
        }
    }

    var idct: IDCT = undefined;
    idct.init(mat);
    var res: [64]f32 = undefined;
    idct.perform(&res);

    return res;
}

// Inverse Discrete Cosine Transformation
const IDCT = struct {
    const precision = 8;
    const coeffs: [64]f32 = generateCoeffs();

    table: [64]u8,

    fn generateCoeffs() [64]f32 {
        var temp: [64]f32 = undefined;
        for (temp) |*c, ind| {
            const x: usize = ind % 8;
            const y: usize = ind / 8;
            c.* = normCoeff(y) * @cos((2.0 * @intToFloat(f32, x) + 1.0) * @intToFloat(f32, y) * std.math.pi / 16.0);
        }
        return temp;
    }

    fn normCoeff(y: usize) f32 {
        return if (y == 0) 1.0 / @sqrt(8.0) else 1.0;
    }

    pub fn init(self: *IDCT, mat: [64]u8) void {
        for (self.table) |*c, ind|
            c.* = mat[zig_zag[ind]];
    }

    pub fn perform(self: *IDCT, out: *[64]f32) void {
        var x: usize = 0;
        while (x < 8) : (x += 1) {
            var y: usize = 0;
            while (y < 8) : (y += 1) {
                var local_sum: f32 = 0;
                var u: usize = 0;
                while (u < 8) : (u += 1) {
                    var v: usize = 0;
                    while (v < 8) : (v += 1)
                        local_sum += @intToFloat(f32, self.table[u + v * 8]) * coeffs[x + u * 8] * coeffs[y + v * 8];
                }
                out.*[x + y * 8] = local_sum / 4;
            }
        }
    }
};
