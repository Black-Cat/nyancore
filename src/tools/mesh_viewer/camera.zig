const nm = @import("../../math/math.zig");

pub const Camera = struct {
    pub const ProjectionType = enum { perspective, orthographic };

    target: nm.vec3,
    position: nm.vec3,
    up: nm.vec3, // Length is used as ortho camera scale

    zoomFn: fn (self: *Camera, dir: f32) void = zoomPerspective,
    projectionFn: fn (self: *Camera, fov_y: f32, aspect: f32, near: f32, far: f32) nm.mat4x4 = projectionPerspective,
    projectionRayFn: fn (self: *Camera, world_pos: nm.vec3) nm.ray = projectionRayPerspective,

    // Dir expected to be normalized
    pub fn viewAlong(self: *Camera, dir: nm.vec3, up: nm.vec3) void {
        const dist: f32 = nm.Vec3.norm(self.position - self.target);
        self.position = self.target - dir * @as(nm.vec3, @splat(dist));
        self.up = up;
    }

    pub fn setDist(self: *Camera, dist: f32) void {
        const dir: nm.vec3 = nm.Vec3.normalize(self.position - self.target);
        self.position = self.target + dir * @as(nm.vec3, @splat(dist));
    }

    pub fn moveTargetTo(self: *Camera, pos: nm.vec3) void {
        const dir: nm.vec3 = self.position - self.target;
        self.target = pos;
        self.position = self.target - dir;
    }

    pub fn setProjection(self: *Camera, projection: ProjectionType) void {
        switch (projection) {
            .orthographic => {
                self.projectionFn = projectionOrthographic;
                self.projectionRayFn = projectionRayOrthographic;
                self.zoomFn = zoomOrthographic;
            },
            .perspective => {
                self.projectionFn = projectionPerspective;
                self.projectionRayFn = projectionRayPerspective;
                self.zoomFn = zoomPerspective;
                self.up = nm.Vec3.normalize(self.up);
            },
        }
    }

    pub fn zoomPerspective(self: *Camera, dir: f32) void {
        var forward: nm.vec3 = self.position - self.target;

        const dst: f32 = nm.Vec3.norm(forward);
        const new_dst: f32 = dst + dir * @log(dst);

        forward = nm.Vec3.normalize(forward);
        self.position = self.target + forward * @as(nm.vec3, @splat(new_dst));
    }

    pub fn zoomOrthographic(self: *Camera, dir: f32) void {
        self.up = nm.Vec3.normalize(self.up) * @as(nm.vec3, @splat(nm.Vec3.norm(self.up) + dir));
    }

    pub fn projectionPerspective(self: *Camera, fov_y: f32, aspect: f32, near: f32, far: f32) nm.mat4x4 {
        _ = self;
        return nm.Mat4x4.perspective(fov_y, aspect, near, far);
    }

    pub fn projectionOrthographic(self: *Camera, fov_y: f32, aspect: f32, near: f32, far: f32) nm.mat4x4 {
        _ = fov_y;
        return nm.Mat4x4.ortho(nm.Vec3.norm(self.up), aspect, near, far);
    }

    pub fn projectionRayPerspective(self: *Camera, world_pos: nm.vec3) nm.ray {
        return .{
            .pos = self.position,
            .dir = nm.Vec3.normalize(world_pos - self.position),
        };
    }

    pub fn projectionRayOrthographic(self: *Camera, world_pos: nm.vec3) nm.ray {
        return .{
            .pos = world_pos,
            .dir = nm.Vec3.normalize(self.target - self.position),
        };
    }

    pub fn viewMatrix(self: *Camera) nm.mat4x4 {
        return nm.Mat4x4.lookAt(self.position, self.target, self.up);
    }
};
