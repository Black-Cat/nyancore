const std = @import("std");

const Image = @import("image.zig").Image;
const printError = @import("../application/print_error.zig").printError;

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
    const HuffmanTreeNode = struct {
        nodes: [2]?*HuffmanTreeNode = .{null} ** 2,
        symbol: ?u8 = null,

        pub fn bitsFromLength(self: *HuffmanTreeNode, symbol_to_add: u8, pos: usize, allocator: std.mem.Allocator) bool {
            if (pos == 0) {
                if (self.nodes[1] != null)
                    return false;
                var symbol_node: *HuffmanTreeNode = allocator.create(HuffmanTreeNode) catch unreachable;
                symbol_node.* = .{};
                symbol_node.symbol = symbol_to_add;
                for (self.nodes) |*n| {
                    if (n.* == null) {
                        n.* = symbol_node;
                        return true;
                    }
                }
            }

            for (self.nodes) |*n| {
                if (n.* == null) {
                    n.* = allocator.create(HuffmanTreeNode) catch unreachable;
                    n.*.?.* = .{};
                }
                if (n.*.?.bitsFromLength(symbol_to_add, pos - 1, allocator))
                    return true;
            }

            return false;
        }

        pub fn deinit(self: *HuffmanTreeNode, allocator: std.mem.Allocator) void {
            for (self.nodes) |*n| {
                if (n.*) |nn| {
                    if (nn.symbol == null)
                        nn.deinit(allocator);
                    allocator.destroy(nn);
                }
            }
        }
    };

    allocator: std.mem.Allocator,

    ht_number: u4,
    ht_type: u1, // 0 = DC, 1 = AC
    symbols_count: [16]u8,
    symbols: []u8,

    tree_root: HuffmanTreeNode,

    pub fn parse(reader: anytype, allocator: std.mem.Allocator) !HuffmanTable {
        var table: HuffmanTable = undefined;
        table.allocator = allocator;

        _ = try reader.readIntBig(u16); // Chunk length

        const ht_information: u8 = try reader.readIntBig(u8);
        table.ht_number = @truncate(u4, ht_information);
        table.ht_type = @truncate(u1, ht_information >> 4);

        _ = try reader.readAll(table.symbols_count[0..]);

        var total_symbol_count: usize = 0;
        for (table.symbols_count) |sc|
            total_symbol_count += sc;

        table.symbols = allocator.alloc(u8, total_symbol_count) catch unreachable;
        _ = try reader.readAll(table.symbols);

        table.tree_root = .{};
        table.initTree();

        return table;
    }

    pub fn deinit(self: *HuffmanTable) void {
        self.allocator.free(self.symbols);

        self.tree_root.deinit(self.allocator);
    }

    fn initTree(self: *HuffmanTable) void {
        var symbols_ind: usize = 0;
        for (self.symbols_count) |sc, l| {
            var left: usize = sc;
            while (left > 0) : (left -= 1) {
                _ = self.tree_root.bitsFromLength(self.symbols[symbols_ind], l, self.allocator);
                symbols_ind += 1;
            }
        }
    }

    pub fn getNextSymbol(self: *HuffmanTable, bit_reader: anytype) !u8 {
        var node: *HuffmanTreeNode = &self.tree_root;
        var out_bits: usize = undefined;

        while (true) {
            var bit: usize = try bit_reader.readBits(usize, 1, &out_bits);
            node = node.nodes[bit].?;
            if (node.symbol) |s|
                return s;
        }
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
    successive_approx: u8,

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
        scan.successive_approx = try reader.readIntBig(u8);

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

    var data_stream = std.io.fixedBufferStream(scan_data.data);
    var bit_reader = std.io.bitReader(.Big, data_stream.reader());

    var lumd_coeff: u32 = 0;
    var cbd_coeff: u32 = 0;
    var crd_coeff: u32 = 0;

    var y: usize = 0;
    while (y < @divExact(frame.height, 8)) : (y += 1) {
        var x: usize = 0;
        while (x < @divExact(frame.width, 8)) : (x += 1) {
            var mat_l: [64]f32 = try buildMatrix(
                &bit_reader,
                0,
                &huffman_tables,
                &quantization_tables[frame.components[0].quantization_table],
                &lumd_coeff,
            );
            _ = mat_l;

            var mat_cr: [64]f32 = try buildMatrix(
                &bit_reader,
                1,
                &huffman_tables,
                &quantization_tables[frame.components[1].quantization_table],
                &crd_coeff,
            );
            _ = mat_cr;

            var mat_cb: [64]f32 = try buildMatrix(
                &bit_reader,
                1,
                &huffman_tables,
                &quantization_tables[frame.components[2].quantization_table],
                &cbd_coeff,
            );
            _ = mat_cb;
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
    var code: u8 = try huffman_tables[idx].getNextSymbol(bit_reader);
    var unused: usize = undefined;
    var bits: u32 = try bit_reader.readBits(u32, code, &unused);
    coef.* += decodeNumber(code, bits);

    var mat: [64]u8 = .{0} ** 64;
    mat[0] = @intCast(u8, coef.*) * quant.values[0];

    var l: usize = 1;
    while (l < 64) {
        code = try huffman_tables[2 + idx].getNextSymbol(bit_reader);
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
        return if (y == 0) 1.0 / @sqrt(2.0) else 1.0;
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
