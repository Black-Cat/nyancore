const nm = @import("../../../math/math.zig");

const Mesh = @import("../../../vulkan_wrapper/mesh.zig").Mesh;
const Model = @import("../../../model/model.zig").Model;

pub const RenderObject = struct {
    transform: nm.mat4x4 = nm.Mat4x4.identity(),
    mesh: Mesh = undefined,

    pub fn initFromModel(self: *RenderObject, model: *Model) void {
        self.mesh.initFromModel(model);
        self.transform = model.transform;
    }

    pub fn deinit(self: *RenderObject) void {
        self.mesh.destroy();
    }
};
