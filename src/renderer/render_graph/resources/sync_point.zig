const RGResource = @import("../render_graph_resource.zig").RGResource;

pub const SyncPoint = struct {
    rg_resource: RGResource,
};
