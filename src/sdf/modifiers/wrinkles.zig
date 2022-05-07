const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Wrinkles",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
};

pub const Data = struct {
    power: f32,
    frequency: f32,
    magnitude: f32,

    enter_index: usize,
    enter_stack: usize,
};

const function_definition: []const u8 =
    \\float opWrinkle(float d, vec3 p, float r, float power, float freq, float mag){
    \\  return d - power * abs(sin(freq * r)) * exp(-mag * abs(r));
    \\}
    \\
;

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, 0);

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const format: []const u8 = "float d{d} = opWrinkle(d{d}, {s}, d{d}, {d:.5}, {d:.5}, {d:.5});";
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (data.enter_index + 2 > ctxt.last_value_set_index) {
        res = util.std.fmt.allocPrint(ctxt.allocator, broken_stack, .{data.enter_index}) catch unreachable;
    } else {
        res = util.std.fmt.allocPrint(ctxt.allocator, format, .{
            data.enter_index,
            ctxt.value_indexes.items[ctxt.value_indexes.items.len - 2].index,
            ctxt.cur_point_name,
            ctxt.last_value_set_index,
            data.power,
            data.frequency,
            data.magnitude,
        }) catch unreachable;
    }

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
