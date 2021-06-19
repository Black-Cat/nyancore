const vk = @import("vulkan");

pub const Chunk = struct {
    size: u32,

    fn init(size: u32) !void {
        this.size = size;
    }
};
