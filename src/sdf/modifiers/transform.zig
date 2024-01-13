const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Transform",
    .data_size = @sizeOf(Data),

    .function_definition = "",
    .enter_command_fn = enterCommand,
    .exit_command_fn = exitCommand,
    .sphere_bound_fn = sphereBound,
};

pub const Data = struct {
    rotation: util.math.vec3,
    translation: util.math.vec3,
    transform_matrix: util.math.mat4x4,
};

pub fn initZero(buffer: *[]u8) void {
    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    data.rotation = util.math.Vec3.zeros();
    data.translation = util.math.Vec3.zeros();
    data.transform_matrix = util.math.Mat4x4.identity();
}

pub fn translate(buffer: *[]u8, v: util.math.vec3) void {
    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    data.translation += v;
}

pub fn updateMatrix(buffer: *[]u8) void {
    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    data.transform_matrix = util.math.Mat4x4.identity();
    util.math.Transform.rotateX(&data.transform_matrix, -data.rotation[0]);
    util.math.Transform.rotateY(&data.transform_matrix, -data.rotation[1]);
    util.math.Transform.rotateZ(&data.transform_matrix, -data.rotation[2]);
    util.math.Transform.translate(&data.transform_matrix, -data.translation);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const temp: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "mat4({d:.5},{d:.5},{d:.5},{d:.5}, {d:.5},{d:.5},{d:.5},{d:.5}, {d:.5},{d:.5},{d:.5},{d:.5}, {d:.5},{d:.5},{d:.5},{d:.5})", .{
        data.transform_matrix[0][0],
        data.transform_matrix[0][1],
        data.transform_matrix[0][2],
        data.transform_matrix[0][3],
        data.transform_matrix[1][0],
        data.transform_matrix[1][1],
        data.transform_matrix[1][2],
        data.transform_matrix[1][3],
        data.transform_matrix[2][0],
        data.transform_matrix[2][1],
        data.transform_matrix[2][2],
        data.transform_matrix[2][3],
        data.transform_matrix[3][0],
        data.transform_matrix[3][1],
        data.transform_matrix[3][2],
        data.transform_matrix[3][3],
    }) catch unreachable;

    const format: []const u8 = "vec3 {s} = ({s} * vec4({s}, 1.)).xyz;";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        next_point,
        temp,
        ctxt.cur_point_name,
    }) catch unreachable;

    ctxt.pushPointName(next_point);

    ctxt.allocator.free(temp);

    return res;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = buffer;

    ctxt.popPointName();
    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn sphereBound(buffer: *[]u8, bound: *util.math.sphereBound, children: []util.math.sphereBound) void {
    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    bound.* = children[0];
    bound.*.pos += data.translation;
}
