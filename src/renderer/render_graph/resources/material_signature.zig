const Model = @import("../../../model/model.zig").Model;

pub const MaterialSignature = packed struct {
    use_positions: bool,
    use_normals: bool,
    use_colors: bool,
    _reserved_bit_3: bool = false,
    _reserved_bit_4: bool = false,
    _reserved_bit_5: bool = false,
    _reserved_bit_6: bool = false,
    _reserved_bit_7: bool = false,
    _reserved_bit_8: bool = false,
    _reserved_bit_9: bool = false,
    _reserved_bit_10: bool = false,
    _reserved_bit_11: bool = false,
    _reserved_bit_12: bool = false,
    _reserved_bit_13: bool = false,
    _reserved_bit_14: bool = false,
    _reserved_bit_15: bool = false,
    _reserved_bit_16: bool = false,
    _reserved_bit_17: bool = false,
    _reserved_bit_18: bool = false,
    _reserved_bit_19: bool = false,
    _reserved_bit_20: bool = false,
    _reserved_bit_21: bool = false,
    _reserved_bit_22: bool = false,
    _reserved_bit_23: bool = false,
    _reserved_bit_24: bool = false,
    _reserved_bit_25: bool = false,
    _reserved_bit_26: bool = false,
    _reserved_bit_27: bool = false,
    _reserved_bit_28: bool = false,
    _reserved_bit_29: bool = false,
    _reserved_bit_30: bool = false,
    _reserved_bit_31: bool = false,

    pub fn createFromModel(model: *Model) MaterialSignature {
        return .{
            .use_positions = model.positions != null,
            .use_normals = model.normals != null,
            .use_colors = model.colors != null,
        };
    }

    pub fn toInt(self: *const MaterialSignature) u32 {
        return @bitCast(u32, self.*);
    }
};
