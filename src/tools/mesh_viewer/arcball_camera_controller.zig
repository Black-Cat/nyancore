const c = @import("../../c.zig");
const nm = @import("../../math/math.zig");

const Camera = @import("camera.zig").Camera;

const mouse_button: u32 = 2;

const ControllerState = enum {
    not_active,
    orbiting,
    panning,
    zooming,
    dolly_zooming,
};

pub const ArcballCameraController = struct {
    state: ControllerState = .not_active,
    last_mouse_pos: c.ImVec2 = undefined,

    camera: *Camera,

    // Must be called right after imgui element that controls camera
    pub fn handleInput(self: *ArcballCameraController) void {
        const io: *c.ImGuiIO = c.igGetIO();

        self.camera.zoomFn(self.camera, -io.MouseWheel);

        if (c.igIsMouseDown(mouse_button) and self.state == .not_active) {
            c.igGetMousePos(&self.last_mouse_pos);
            if (io.KeyShift and io.KeyCtrl) {
                self.state = .dolly_zooming;
            } else if (io.KeyShift) {
                self.state = .panning;
            } else if (io.KeyCtrl) {
                self.state = .zooming;
            } else {
                self.state = .orbiting;
            }
            return;
        }

        if (self.state != .not_active and !c.igIsMouseDown(mouse_button)) {
            self.state = .not_active;
            return;
        }

        var cur_pos: c.ImVec2 = undefined;
        c.igGetMousePos(&cur_pos);

        const dir: c.ImVec2 = .{
            .x = (cur_pos.x - self.last_mouse_pos.x) * 0.01,
            .y = -(cur_pos.y - self.last_mouse_pos.y) * 0.01,
        };

        if (self.state == .orbiting) {
            const old_up: nm.vec3 = self.camera.up;
            var old_forward: nm.vec3 = self.camera.position - self.camera.target;
            const old_right: nm.vec3 = nm.Vec3.cross(old_forward, old_up);

            self.camera.up = nm.Vec3.rotate(self.camera.up, dir.x, old_up);
            self.camera.up = nm.Vec3.rotate(self.camera.up, dir.y, old_right);

            old_forward = nm.Vec3.rotate(old_forward, dir.x, old_up);
            old_forward = nm.Vec3.rotate(old_forward, dir.y, old_right);
            self.camera.position = self.camera.target + old_forward;
        } else if (self.state == .panning) {
            var offset: nm.vec3 = self.camera.up * @splat(3, dir.y);

            const forward: nm.vec3 = self.camera.position - self.camera.target;

            var right: nm.vec3 = nm.Vec3.cross(forward, self.camera.up);
            right = nm.Vec3.normalize(right) * @splat(3, -dir.x);

            offset += right;

            self.camera.position += offset;
            self.camera.target += offset;
        } else if (self.state == .zooming) {
            self.camera.zoomFn(self.camera, -dir.y);
        } else if (self.state == .dolly_zooming) {
            var forward: nm.vec3 = self.camera.target - self.camera.position;
            forward = nm.Vec3.normalize(forward);
            forward *= @splat(3, dir.y);
            self.camera.target += forward;
            self.camera.position += forward;
        }

        self.last_mouse_pos = cur_pos;
    }
};
