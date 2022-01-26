pub const std = @import("std");
pub const math = @import("../math/math.zig");
pub const SdfInfo = @import("sdf_info.zig").SdfInfo;
pub const IterationContext = @import("iteration_context.zig").IterationContext;

pub fn combinatorExitCommand(comptime command: []const u8, enter_stack: usize, enter_index: usize, ctxt: *IterationContext) []const u8 {
    const define_command: []const u8 = "float " ++ command;
    const add_command: []const u8 = "{s}\n" ++ command;
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (enter_stack + 2 >= ctxt.value_indexes.items.len) {
        res = std.fmt.allocPrint(ctxt.allocator, broken_stack, .{enter_index}) catch unreachable;
    } else {
        res = std.fmt.allocPrint(ctxt.allocator, define_command, .{
            enter_index,
            ctxt.value_indexes.items[enter_stack + 1].index,
            ctxt.value_indexes.items[enter_stack + 2].index,
        }) catch unreachable;

        for (ctxt.value_indexes.items[enter_stack + 3 ..]) |item| {
            var temp: []const u8 = std.fmt.allocPrint(ctxt.allocator, add_command, .{
                res,
                enter_index,
                enter_index,
                item.index,
            }) catch unreachable;

            ctxt.allocator.free(res);
            res = temp;
        }
    }

    return res;
}

pub fn smoothCombinatorExitCommand(comptime command: []const u8, enter_stack: usize, enter_index: usize, ctxt: *IterationContext, smoothness: f32) []const u8 {
    const define_command: []const u8 = "float " ++ command;
    const add_command: []const u8 = "{s}\n" ++ command;
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (enter_stack + 2 >= ctxt.value_indexes.items.len) {
        res = std.fmt.allocPrint(ctxt.allocator, broken_stack, .{enter_index}) catch unreachable;
    } else {
        res = std.fmt.allocPrint(ctxt.allocator, define_command, .{
            enter_index,
            ctxt.value_indexes.items[enter_stack + 1].index,
            ctxt.value_indexes.items[enter_stack + 2].index,
            smoothness,
        }) catch unreachable;

        for (ctxt.value_indexes.items[enter_stack + 3 ..]) |item| {
            var temp: []const u8 = std.fmt.allocPrint(ctxt.allocator, add_command, .{
                res,
                enter_index,
                enter_index,
                item.index,
                smoothness,
            }) catch unreachable;

            ctxt.allocator.free(res);
            res = temp;
        }
    }

    return res;
}
