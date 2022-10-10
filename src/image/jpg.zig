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

// Without header
pub fn parse(reader: anytype, allocator: std.mem.Allocator) !Image {
    var image: Image = undefined;
    image.width = 0;
    image.height = 0;
    image.data = allocator.alloc(u8, 100) catch unreachable;

    var huffman_tables: [4]HuffmanTable = undefined;
    defer for (huffman_tables) |*ht| ht.deinit();
    var current_huffman_table: usize = 0;

    var quantization_tables: [2]QuantizationTable = undefined;
    defer for (quantization_tables) |*qt| qt.deinit();
    var current_quantization_table: usize = 0;

    var marker: u16 = undefined;
    var chunk_length: u16 = undefined;

    while (true) {
        marker = try reader.readIntBig(u16);

        switch (marker) {
            0xFFDA => break,
            0xFFC4 => {
                huffman_tables[current_huffman_table] = try HuffmanTable.parse(reader, allocator);
                current_huffman_table += 1;
            },
            0xFFDB => {
                quantization_tables[current_quantization_table] = try QuantizationTable.parse(reader, allocator);
                current_quantization_table += 1;
            },
            else => {
                chunk_length = try reader.readIntBig(u16);
                try reader.skipBytes(chunk_length - 2, .{});
            },
        }
    }

    if (quantization_tables[0].number != 0)
        std.mem.swap(QuantizationTable, &quantization_tables[0], &quantization_tables[1]);

    return image;
}
