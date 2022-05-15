pub const std = @import("std");
pub const math = @import("../math/math.zig");
pub const sdf = @import("sdf.zig");
pub const SdfInfo = @import("sdf_info.zig").SdfInfo;
pub const IterationContext = @import("iteration_context.zig").IterationContext;
pub const EnterInfo = IterationContext.EnterInfo;

pub fn combinatorExitCommand(comptime command: []const u8, enter_stack: usize, enter_index: usize, ctxt: *IterationContext) []const u8 {
    const define_command: []const u8 = "float " ++ command;
    const add_command: []const u8 = "{s}\n" ++ command;
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (enter_stack + 1 >= ctxt.value_indexes.items.len) {
        res = std.fmt.allocPrint(ctxt.allocator, broken_stack, .{enter_index}) catch unreachable;
    } else if (enter_stack + 2 >= ctxt.value_indexes.items.len) {
        res = std.fmt.allocPrint(ctxt.allocator, "float d{d} = d{d};", .{ enter_index, ctxt.value_indexes.items[enter_stack + 1].index }) catch unreachable;
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

pub fn surfaceEnterCommand(comptime DataT: type) sdf.EnterCommandFn {
    const s = struct {
        fn f(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
            const data: *DataT = @ptrCast(*DataT, @alignCast(@alignOf(DataT), buffer.ptr));

            ctxt.pushEnterInfo(iter);
            ctxt.pushStackInfo(iter, @intCast(i32, data.mat + mat_offset));

            return std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
        }
    };
    return s.f;
}

pub fn surfaceExitCommand(
    comptime DataT: type,
    exitCommandFn: fn (data: *DataT, enter_index: usize, cur_point_name: []const u8, allocator: std.mem.Allocator) []const u8,
) sdf.ExitCommandFn {
    const s = struct {
        fn f(ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 {
            _ = iter;
            const data: *DataT = @ptrCast(*DataT, @alignCast(@alignOf(DataT), buffer.ptr));

            const ei: EnterInfo = ctxt.lastEnterInfo();
            const res: []const u8 = exitCommandFn(data, ei.enter_index, ctxt.cur_point_name, ctxt.allocator);

            ctxt.dropPreviousValueIndexes(ei.enter_stack);

            return res;
        }
    };
    return s.f;
}

pub fn surfaceMatCheckCommand(comptime DataT: type) sdf.AppendMatCheckFn {
    const s = struct {
        fn f(ctxt: *IterationContext, exit_command: []const u8, buffer: *[]u8, mat_offset: usize, allocator: std.mem.Allocator) []const u8 {
            const data: *DataT = @ptrCast(*DataT, @alignCast(@alignOf(DataT), buffer.ptr));

            const ei: EnterInfo = ctxt.popEnterInfo();
            const formatMat: []const u8 = "{s}if(d{d}<MAP_EPS)return matToColor({d}.,l,n,v);";
            return std.fmt.allocPrint(allocator, formatMat, .{
                exit_command,
                ei.enter_index,
                data.mat + mat_offset,
            }) catch unreachable;
        }
    };
    return s.f;
}
