const rg = @import("../render_graph.zig");
const vk = @import("../../../vk.zig");
const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../../../vulkan_wrapper/vulkan_functions.zig");

const Buffer = @import("../../../vulkan_wrapper/buffer.zig").Buffer;
const SingleCommandBuffer = @import("../../../vulkan_wrapper/single_command_buffer.zig").SingleCommandBuffer;
const Texture = @import("texture.zig").Texture;

pub const TransferContext = struct {
    pub fn transfer(target: *Texture, final_layout: vk.ImageLayout, data: []u8) void {
        var transfer_buffer: Buffer = undefined;
        transfer_buffer.init(data.len, .{ .transfer_src_bit = true }, .sequential);
        defer transfer_buffer.destroy();

        @memcpy(@ptrCast([*]u8, transfer_buffer.allocation.mapped_memory), data.ptr, data.len);

        var scb: SingleCommandBuffer = SingleCommandBuffer.allocate(&rg.global_render_graph.command_pool) catch unreachable;
        scb.command_buffer.beginSingleTimeCommands();

        target.transitionImageLayout(scb.command_buffer.vk_ref, .@"undefined", .transfer_dst_optimal);

        const region: vk.BufferImageCopy = .{
            .buffer_offset = 0,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .base_array_layer = 0,
                .layer_count = 1,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = target.extent,
        };

        vkfn.d.cmdCopyBufferToImage(scb.command_buffer.vk_ref, transfer_buffer.vk_ref, target.image, .transfer_dst_optimal, 1, @ptrCast([*]const vk.BufferImageCopy, &region));

        target.transitionImageLayout(scb.command_buffer.vk_ref, .transfer_dst_optimal, final_layout);

        scb.command_buffer.endSingleTimeCommands();
        scb.submit(vkctxt.graphics_queue);
    }
};
