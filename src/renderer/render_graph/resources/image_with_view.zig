const vk = @import("../../../vk.zig");

const RGResource = @import("../render_graph_resource.zig").RGResource;

const Image = @import("../../../vulkan_wrapper/image.zig").Image;
const ImageView = @import("../../../vulkan_wrapper/image_view.zig").ImageView;

pub const ImageWithView = struct {
    image: Image,
    view: ImageView,

    pub fn init(self: *ImageWithView, extent: vk.Extent3D, format: vk.Format, usage_flags: vk.ImageUsageFlags) void {
        self.image.init(format, usage_flags, extent);
        self.view.init(&self.image);
    }

    pub fn deinit(self: *ImageWithView) void {
        self.image.deinit();
        self.view.deinit();
    }

    pub fn resize(self: *ImageWithView, extent: vk.Extent3D) void {
        self.image.resize(extent);
        self.view.recreate();
    }
};
