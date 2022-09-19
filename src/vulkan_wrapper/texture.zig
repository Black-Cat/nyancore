const vk = @import("../vk.zig");

const Image = @import("image.zig").Image;
const ImageView = @import("image_view.zig").ImageView;

pub const Texture = struct {
    image: Image,
    view: ImageView,

    pub fn init(self: *Texture, extent: vk.Extent3D, format: vk.Format, usage_flags: vk.ImageUsageFlags) void {
        self.image.init(format, usage_flags, extent, .@"undefined");
        self.view.init(&self.image);
    }

    pub fn deinit(self: *Texture) void {
        self.view.destroy();
        self.image.destroy();
    }

    pub fn resize(self: *Texture, extent: vk.Extent3D) void {
        self.image.resize(extent);
        self.view.recreate();
    }
};
