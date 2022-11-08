const std = @import("std");

const nm = @import("../math/math.zig");

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
    std.mem.set(u8, image.data, 255);

    var component_buffers: [][]u8 = allocator.alloc([]u8, frame.components.len) catch unreachable;
    for (frame.components) |c, c_ind| {
        const to_upsample: bool = !(c.sampling_factor_vertical == comp_max_v and c.sampling_factor_horizontal == comp_max_h);
        const buffer_size: usize = if (to_upsample) mcu_x * mcu_y * 8 * 8 * c.sampling_factor_horizontal * c.sampling_factor_vertical else 0;
        component_buffers[c_ind] = allocator.alloc(u8, buffer_size) catch unreachable;
    }
    defer allocator.free(component_buffers);
    defer for (component_buffers) |cb| allocator.free(cb);

    var mcu_index: usize = 0;
    while (mcu_index < mcu_x * mcu_y) : (mcu_index += 1) {
        const mcu_index_x = mcu_index % mcu_x;
        const mcu_index_y = mcu_index / mcu_y;

        for (frame.components) |c, c_ind| {
            const to_upsample: bool = !(c.sampling_factor_vertical == comp_max_v and c.sampling_factor_horizontal == comp_max_h);

            // If image doesn't need to be upsampled, write directly to image data
            const stride: [2]usize = if (to_upsample) .{ 1, mcu_x * 8 * c.sampling_factor_horizontal } else .{ 4, image.width * 4 };
            const target_slice: []u8 = if (to_upsample) component_buffers[c_ind] else image.data[c.id - 1 ..];

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

                    const coor_x: usize = (mcu_index_x * c.sampling_factor_horizontal + j) * 8;
                    const coor_y: usize = (mcu_index_y * c.sampling_factor_vertical + i) * 8;
                    const sampled_pos: usize = coor_y * stride[1] + coor_x * stride[0];
                    performIDCT(target_slice[sampled_pos..], stride, block);
                }
            }
        }
    }

    // Linear upsampling
    for (frame.components) |c, c_ind| {
        if (comp_max_h == c.sampling_factor_horizontal and comp_max_v == c.sampling_factor_vertical)
            continue;

        const hor_stride: usize = comp_max_h - c.sampling_factor_horizontal + 1;
        const ver_stride: usize = comp_max_v - c.sampling_factor_vertical + 1;

        const h: f32 = @intToFloat(f32, hor_stride);
        const v: f32 = @intToFloat(f32, ver_stride);

        const sample_pos: [9]nm.vec2 = .{
            .{ -h, -v },
            .{ 0.0, -v },
            .{ h, -v },
            .{ -h, 0.0 },
            .{ 0.0, 0.0 },
            .{ h, 0.0 },
            .{ -h, v },
            .{ 0.0, v },
            .{ h, v },
        };
        const kernel_offset: nm.vec2 = .{ -h / 2.0, -v / 2.0 };

        var kernel: [][9]f32 = allocator.alloc([9]f32, hor_stride * ver_stride) catch unreachable;
        defer allocator.free(kernel);

        var yk: usize = 0;
        while (yk < ver_stride) : (yk += 1) {
            var xk: usize = 0;
            while (xk < hor_stride) : (xk += 1) {
                const pos: nm.vec2 = nm.vec2{ @intToFloat(f32, xk) + 0.5, @intToFloat(f32, yk) + 0.5 } + kernel_offset;

                var sum: f32 = 0.0;
                for (sample_pos) |sp, sp_ind| {
                    const dist: f32 = nm.Vec2.norm(pos - sp);
                    kernel[yk * ver_stride + xk][sp_ind] = dist;
                    sum += dist;
                }

                for (kernel[yk * ver_stride + xk]) |*k|
                    k.* /= sum;
            }
        }

        var cur_block: [9]u8 = .{undefined} ** 9;

        var y: usize = 0;
        while (y < mcu_y * 8 * c.sampling_factor_vertical) : (y += 1) {
            const y_values: [3]usize = .{
                if (y == 0) y else y - 1,
                y,
                if (y == mcu_y * 8 * c.sampling_factor_vertical - 1) y else y + 1,
            };

            const x_values: [2]usize = .{ 0, 1 };
            for (x_values) |ox, ox_ind| {
                for (y_values) |oy, oy_ind|
                    cur_block[oy_ind * 3 + ox_ind + 1] = component_buffers[c_ind][oy * mcu_x * 8 * c.sampling_factor_horizontal + ox + 1];
            }

            var x: usize = 0;
            while (x < mcu_x * 8 * c.sampling_factor_horizontal) : (x += 1) {
                cur_block[0] = cur_block[1];
                cur_block[1] = cur_block[2];
                cur_block[3] = cur_block[4];
                cur_block[4] = cur_block[5];
                cur_block[6] = cur_block[7];
                cur_block[7] = cur_block[8];

                const ox: usize = if (x == mcu_x * 8 * c.sampling_factor_horizontal - 1) x else x + 1;
                const offseted_indexes: [3]usize = .{ 2, 5, 8 };

                for (offseted_indexes) |oi, oi_ind|
                    cur_block[oi] = component_buffers[c_ind][y_values[oi_ind] * mcu_x * 8 * c.sampling_factor_horizontal + ox];

                const start_ind: usize = (y * image.width * ver_stride + x * hor_stride) * 4 + c.id - 1;
                var vs: usize = 0;
                while (vs < ver_stride) : (vs += 1) {
                    var hs: usize = 0;
                    while (hs < hor_stride) : (hs += 1) {
                        var val: f32 = 0.0;
                        for (kernel[vs * hor_stride + hs]) |k, k_ind|
                            val += k * @intToFloat(f32, cur_block[k_ind]);
                        image.data[start_ind + (vs * image.width + hs) * 4] = @floatToInt(u8, @minimum(255.0, val));
                    }
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
// Adapted from float Pennebaker & Mitchell JPEG textbook and libjpeg-turbo library (float variant)
pub fn performIDCT(out: []u8, out_stride: [2]usize, data: [64]i32) void {
    var tmp: [14]f32 = .{undefined} ** 14;

    var z5: f32 = undefined;
    var z10: f32 = undefined;
    var z11: f32 = undefined;
    var z12: f32 = undefined;
    var z13: f32 = undefined;

    var workspace: [64]f32 = .{0.0} ** 64;

    var out_slice: []u8 = undefined;
    var ws_slice: []f32 = undefined;
    var data_slice: []const i32 = undefined;

    const stride: usize = 8;

    // Process collumns
    var col: usize = 0;
    while (col < 8) : (col += 1) {
        ws_slice = workspace[col..];
        data_slice = data[col..];

        // Even
        tmp[0] = @intToFloat(f32, data_slice[0 * stride]) * 0.125;
        tmp[1] = @intToFloat(f32, data_slice[2 * stride]) * 0.125;
        tmp[2] = @intToFloat(f32, data_slice[4 * stride]) * 0.125;
        tmp[3] = @intToFloat(f32, data_slice[6 * stride]) * 0.125;

        // Phase 3
        tmp[10] = tmp[0] + tmp[2];
        tmp[11] = tmp[0] - tmp[2];

        // Phase 5-3
        tmp[13] = tmp[1] + tmp[3];
        tmp[12] = (tmp[1] - tmp[3]) * 1.414213562 - tmp[13];

        // Phase 2
        tmp[0] = tmp[10] + tmp[13];
        tmp[3] = tmp[10] - tmp[13];
        tmp[1] = tmp[11] + tmp[12];
        tmp[2] = tmp[11] - tmp[12];

        // Odd
        tmp[4] = @intToFloat(f32, data_slice[1 * stride]) * 0.125;
        tmp[5] = @intToFloat(f32, data_slice[3 * stride]) * 0.125;
        tmp[6] = @intToFloat(f32, data_slice[5 * stride]) * 0.125;
        tmp[7] = @intToFloat(f32, data_slice[7 * stride]) * 0.125;

        // Phase 6
        z13 = tmp[6] + tmp[5];
        z10 = tmp[6] - tmp[5];
        z11 = tmp[4] + tmp[7];
        z12 = tmp[4] - tmp[7];

        // Phase 5
        tmp[7] = z11 + z13;
        tmp[11] = (z11 - z13) * 1.414213562;

        z5 = (z10 + z12) * 1.847759065;
        tmp[10] = z5 - z12 * 1.082392200;
        tmp[12] = z5 - z10 * 2.613125930;

        // Phase 2
        tmp[6] = tmp[12] - tmp[7];
        tmp[5] = tmp[11] - tmp[6];
        tmp[4] = tmp[10] - tmp[5];

        ws_slice[0 * stride] = tmp[0] + tmp[7];
        ws_slice[7 * stride] = tmp[0] - tmp[7];
        ws_slice[1 * stride] = tmp[1] + tmp[6];
        ws_slice[6 * stride] = tmp[1] - tmp[6];
        ws_slice[2 * stride] = tmp[2] + tmp[5];
        ws_slice[5 * stride] = tmp[2] - tmp[5];
        ws_slice[3 * stride] = tmp[3] + tmp[4];
        ws_slice[4 * stride] = tmp[3] - tmp[4];
    }

    // Process rows
    var row: usize = 0;
    while (row < 8) : (row += 1) {
        ws_slice = workspace[row * stride ..];
        out_slice = out[row * out_stride[1] ..];

        // Even
        z5 = ws_slice[0] + 128.5;
        tmp[10] = z5 + ws_slice[4];
        tmp[11] = z5 - ws_slice[4];

        tmp[13] = ws_slice[2] + ws_slice[6];
        tmp[12] = (ws_slice[2] - ws_slice[6]) * 1.414213562 - tmp[13];

        tmp[0] = tmp[10] + tmp[13];
        tmp[3] = tmp[10] - tmp[13];
        tmp[1] = tmp[11] + tmp[12];
        tmp[2] = tmp[11] - tmp[12];

        // Odd
        z13 = ws_slice[5] + ws_slice[3];
        z10 = ws_slice[5] - ws_slice[3];
        z11 = ws_slice[1] + ws_slice[7];
        z12 = ws_slice[1] - ws_slice[7];

        tmp[7] = z11 + z13;
        tmp[11] = (z11 - z13) * 1.414213562;

        z5 = (z10 + z12) * 1.847759065;
        tmp[10] = z5 - z12 * 1.082392200;
        tmp[12] = z5 - z10 * 2.613125930;

        tmp[6] = tmp[12] - tmp[7];
        tmp[5] = tmp[11] - tmp[6];
        tmp[4] = tmp[10] - tmp[5];

        out_slice[0 * out_stride[0]] = @floatToInt(u8, std.math.clamp(tmp[0] + tmp[7], 0.0, 255.0));
        out_slice[7 * out_stride[0]] = @floatToInt(u8, std.math.clamp(tmp[0] - tmp[7], 0.0, 255.0));
        out_slice[1 * out_stride[0]] = @floatToInt(u8, std.math.clamp(tmp[1] + tmp[6], 0.0, 255.0));
        out_slice[6 * out_stride[0]] = @floatToInt(u8, std.math.clamp(tmp[1] - tmp[6], 0.0, 255.0));
        out_slice[2 * out_stride[0]] = @floatToInt(u8, std.math.clamp(tmp[2] + tmp[5], 0.0, 255.0));
        out_slice[5 * out_stride[0]] = @floatToInt(u8, std.math.clamp(tmp[2] - tmp[5], 0.0, 255.0));
        out_slice[3 * out_stride[0]] = @floatToInt(u8, std.math.clamp(tmp[3] + tmp[4], 0.0, 255.0));
        out_slice[4 * out_stride[0]] = @floatToInt(u8, std.math.clamp(tmp[3] - tmp[4], 0.0, 255.0));
    }
}
