const util = @import("../sdf_util.zig");

pub const info: util.SdfInfo = .{
    .name = "Oren Nayar",
    .data_size = @sizeOf(Data),

    .function_definition = function_definition,
    .enter_command_fn = enterCommand,
};

pub const Data = struct {
    color: [3]f32,
    roughness: f32,
};

const function_definition: []const u8 =
    \\vec3 matOrenNayar(vec3 l, vec3 n, vec3 v, vec3 col, float r){
    \\  float r2 = r*r;
    \\  float a = 1.-.5*(r2/(r2+.57));
    \\  float b = .45*(r2/(r2+.09));
    \\
    \\  float nl = dot(n,l);
    \\  float nv = dot(n,v);
    \\
    \\  float ga=dot(v-n*nv,n-n*nl);
    \\  return col * max(0.,nl) * (a+b*max(0.,ga)*sqrt((1.-nv*nv)*(1.-nl*nl))/max(nl,nv));
    \\}
    \\
;

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const format: []const u8 = "res = matOrenNayar(l,n,v,vec3({d:.5},{d:.5},{d:.5}),{d:.5});";

    return util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.color[0],
        data.color[1],
        data.color[2],
        data.roughness,
    }) catch unreachable;
}
