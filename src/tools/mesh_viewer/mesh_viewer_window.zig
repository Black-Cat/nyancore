const std = @import("std");

const c = @import("../../c.zig");
const rg = @import("../../renderer/render_graph/render_graph.zig");
const nm = @import("../../math/math.zig");
const vk = @import("../../vk.zig");

const glb = @import("../../model/glb.zig");

const asset = @import("../../application/asset.zig");

const Allocator = std.mem.Allocator;
const Widget = @import("../../ui/widget.zig").Widget;
const Window = @import("../../ui/window.zig").Window;

const ArcballCameraController = @import("arcball_camera_controller.zig").ArcballCameraController;
const Camera = @import("camera.zig").Camera;

const Model = @import("../../model/model.zig").Model;
const MeshPass = @import("../../renderer/render_graph/passes/mesh_pass.zig").MeshPass;
const Swapchain = @import("../../vulkan_wrapper/swapchain.zig").Swapchain;
const SyncPass = @import("../../renderer/render_graph/passes/sync_pass.zig").SyncPass;
const RGPass = @import("../../renderer/render_graph/render_graph_pass.zig").RGPass;

const ImageWithView = @import("../../renderer/render_graph/resources/image_with_view.zig").ImageWithView;

pub const MeshViewerWindow = struct {
    const MAX_FILE_PATH_LEN = 256;

    window: Window,
    allocator: Allocator,

    selected_file_path: [MAX_FILE_PATH_LEN]u8,

    model: Model,
    pass: MeshPass(Swapchain),
    depth_buffer: ImageWithView,
    ui_sync_pass: SyncPass,
    ui_pass: *RGPass,

    camera: Camera,
    camera_controller: ArcballCameraController,

    pub fn init(self: *MeshViewerWindow, name: []const u8, allocator: Allocator, ui_pass: *RGPass) void {
        self.allocator = allocator;
        self.ui_pass = ui_pass;

        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = true,
            .strId = allocator.dupeZ(u8, name) catch unreachable,
        };

        self.camera.target = nm.Vec3.zeros();
        self.camera.position = .{ 0.0, 0.0, -10.0 };
        self.camera.up = .{ 0.0, 1.0, 0.0 };
        self.camera.setProjection(.perspective);
        self.camera_controller = .{ .camera = &self.camera };
    }

    pub fn deinit(self: *MeshViewerWindow) void {
        self.depth_buffer.deinit();
        self.pass.deinit();

        self.allocator.free(self.window.strId);
    }

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *MeshViewerWindow = @fieldParentPtr(MeshViewerWindow, "window", window);

        const extent: vk.Extent3D = .{
            .width = rg.global_render_graph.final_swapchain.image_extent.width,
            .height = rg.global_render_graph.final_swapchain.image_extent.height,
            .depth = 1.0,
        };
        self.depth_buffer.init(extent, .d32_sfloat, .{ .depth_stencil_attachment_bit = true });
        rg.global_render_graph.addResource(&self.depth_buffer, "Depth Buffer");

        self.pass.init("Test Mesh Pass", &rg.global_render_graph.final_swapchain, &self.depth_buffer, &self.camera);
        self.pass.rg_pass.initial_layout = .@"undefined";
        self.pass.rg_pass.final_layout = .color_attachment_optimal;
        self.pass.rg_pass.load_op = .clear;

        rg.global_render_graph.passes.append(&self.pass.rg_pass) catch unreachable;

        self.ui_sync_pass.init("Ui - Mesh Sync Pass", self.allocator);
        rg.global_render_graph.sync_passes.append(&self.ui_sync_pass) catch unreachable;

        self.pass.rg_pass.appendWriteResource(&self.ui_sync_pass.input_sync_point.rg_resource);
        self.ui_pass.appendReadResource(&self.ui_sync_pass.output_sync_point.rg_resource);

        rg.global_render_graph.needs_rebuilding = true;
    }

    fn windowDeinit(widget: *Widget) void {
        _ = widget;
    }

    fn cleanSelectedPath(self: *MeshViewerWindow) void {
        @memcpy(@ptrCast([*]u8, &self.selected_file_path[0]), "", 1);
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *MeshViewerWindow = @fieldParentPtr(MeshViewerWindow, "window", window);

        if (!window.open)
            return;

        _ = c.igBegin(self.window.strId.ptr, &window.open, c.ImGuiWindowFlags_None);

        if (c.igButton("Import Model", .{ .x = 0, .y = 0 })) {
            self.cleanSelectedPath();
            c.igOpenPopup("Import Model", c.ImGuiPopupFlags_None);
        }

        if (c.igButton("Save Asset", .{ .x = 0, .y = 0 })) {
            self.cleanSelectedPath();
            c.igOpenPopup("Save Asset", c.ImGuiPopupFlags_None);
        }

        if (c.igButton("Load Asset", .{ .x = 0, .y = 0 })) {
            self.cleanSelectedPath();
            c.igOpenPopup("Load Asset", c.ImGuiPopupFlags_None);
        }

        self.drawPopup("Import Model", "Import", importModel);
        self.drawPopup("Save Asset", "Save", saveAsset);
        self.drawPopup("Load Asset", "Load", loadAsset);

        c.igEnd();

        self.camera_controller.handleInput();
    }

    fn drawPopup(self: *MeshViewerWindow, comptime name: [*c]const u8, comptime action_name: [*c]const u8, callback: fn (self: *MeshViewerWindow) void) void {
        var open_modal: bool = true;

        if (!c.igBeginPopupModal(name, &open_modal, c.ImGuiWindowFlags_None))
            return;

        if (c.igInputText("Path", @ptrCast([*c]u8, &self.selected_file_path), MAX_FILE_PATH_LEN, c.ImGuiInputTextFlags_EnterReturnsTrue, null, null)) {
            callback(self);
            c.igCloseCurrentPopup();
        }

        if (c.igButton(action_name, .{ .x = 0, .y = 0 })) {
            callback(self);
            c.igCloseCurrentPopup();
        }

        c.igSameLine(200.0, 2.0);
        if (c.igButton("Cancel", .{ .x = 0, .y = 0 }))
            c.igCloseCurrentPopup();

        c.igEndPopup();
    }

    fn importModel(self: *MeshViewerWindow) void {
        const path: []const u8 = std.mem.sliceTo(&self.selected_file_path, 0);

        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = cwd.openFile(path, .{ .read = true }) catch return;
        defer file.close();

        const reader = file.reader();

        _ = glb.check_header(reader) catch return;
        self.model = glb.parse(reader, self.allocator) catch return;
        self.pass.setModel(&self.model);
    }

    fn saveAsset(self: *MeshViewerWindow) void {
        const path: []const u8 = std.mem.sliceTo(&self.selected_file_path, 0);

        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = cwd.createFile(path, .{ .read = true, .truncate = true }) catch return;
        defer file.close();

        const writer = file.writer();

        var map: asset.AssetMap = self.model.generateAssetMap(self.allocator);
        defer Model.deinitAssetMap(&map);

        asset.serializeAsset(writer, "model", map) catch return;
    }

    fn loadAsset(self: *MeshViewerWindow) void {
        const path: []const u8 = std.mem.sliceTo(&self.selected_file_path, 0);

        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = cwd.openFile(path, .{ .read = true }) catch return;
        defer file.close();

        const reader = file.reader();

        var map: asset.AssetMap = asset.deserializeAsset(reader, self.allocator) catch return;
        defer Model.deinitAssetMap(&map);

        self.model = Model.createFromAssetMap(&map, self.allocator);
        self.pass.setModel(&self.model);
    }
};
