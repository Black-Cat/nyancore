const std = @import("std");

const Image = @import("image.zig").Image;
const printError = @import("../application/print_error.zig").printError;

pub fn checkHeader(reader: anytype) !bool {
    const jpg_signature = [_]u8{ 0xFF, 0xD8 };
    return reader.isBytes(&jpg_signature);
}

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

    ht_count: u4,
    ht_type: u1, // 0 = DC, 1 = AC
    symbols_count: [16]u8,
    symbols: []u8,

    tree_root: HuffmanTreeNode,

    pub fn parse(reader: anytype, allocator: std.mem.Allocator) !HuffmanTable {
        var table: HuffmanTable = undefined;
        table.allocator = allocator;

        _ = try reader.readIntBig(u16); // Chunk length

        const ht_information: u8 = try reader.readIntBig(u8);
        table.ht_count = @truncate(u4, ht_information);
        table.ht_type = @truncate(u1, ht_information >> 4);

        _ = try reader.readAll(table.symbols_count[0..]);

        var total_symbol_count: usize = 0;
        for (table.symbols_count) |sc|
            total_symbol_count += sc;

        table.symbols = allocator.alloc(u8, total_symbol_count) catch unreachable;

        var current_symbol: usize = 0;
        for (table.symbols_count) |sc| {
            var symbols_left: usize = sc;
            while (symbols_left > 0) : (symbols_left -= 1) {
                table.symbols[current_symbol] = try reader.readByte();
                current_symbol += 1;
            }
        }

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
            node = node.nodes[bit];
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

        table.values = allocator.alloc(u8, 64 * @intCast(usize, (table.precision + 1))) catch unreachable;
        _ = try reader.readAll(table.values);

        return table;
    }

    pub fn deinit(self: *QuantizationTable) void {
        self.allocator.free(self.values);
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
    pub const Selector = struct {
        dc: u4,
        ac: u4,
    };

    allocator: std.mem.Allocator,

    components: u8,
    selectors: []Selector,
    spectral_select: [2]u8,
    successive_approx: u8,

    data: []u8,

    pub fn parse(reader: anytype, allocator: std.mem.Allocator) !ScanData {
        var scan: ScanData = undefined;
        scan.allocator = allocator;

        _ = try reader.readIntBig(u16); // Chunk length

        scan.components = try reader.readIntBig(u8);
        scan.selectors = allocator.alloc(Selector, scan.components) catch unreachable;
        for (scan.selectors) |_| {
            const index: u8 = try reader.readIntBig(u8);
            const selector_data: u8 = try reader.readIntBig(u8);
            scan.selectors[index - 1].ac = @truncate(u4, selector_data);
            scan.selectors[index - 1].dc = @truncate(u4, selector_data >> 4);
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
        self.allocator.free(self.selectors);
        self.allocator.free(self.data);
    }
};

// Without header
pub fn parse(reader: anytype, allocator: std.mem.Allocator) !Image {
    var huffman_tables: [4]HuffmanTable = undefined;
    defer for (huffman_tables) |*ht| ht.deinit();
    var current_huffman_table: usize = 0;

    var quantization_tables: [2]QuantizationTable = undefined;
    defer for (quantization_tables) |*qt| qt.deinit();
    var current_quantization_table: usize = 0;

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
                huffman_tables[current_huffman_table] = try HuffmanTable.parse(reader, allocator);
                current_huffman_table += 1;
            },
            0xFFDB => {
                quantization_tables[current_quantization_table] = try QuantizationTable.parse(reader, allocator);
                current_quantization_table += 1;
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

    if (quantization_tables[0].number != 0)
        std.mem.swap(QuantizationTable, &quantization_tables[0], &quantization_tables[1]);

    var image: Image = undefined;
    image.width = 0;
    image.height = 0;
    image.data = allocator.alloc(u8, 100) catch unreachable;

    return image;
}
