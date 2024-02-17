pub fn typeId(comptime T: type) usize {
    _ = T;
    const S = struct {
        var byte: u8 = 0;
    };
    return @intFromPtr(&S.byte);
}
