const rg = @import("../renderer/render_graph/render_graph.zig");
const vk = @import("../vk.zig");
const vkctxt = @import("vulkan_context.zig");
const vkfn = @import("vulkan_functions.zig");

const Buffer = @import("buffer.zig").Buffer;
const Image = @import("image.zig").Image;
const SingleCommandBuffer = @import("single_command_buffer.zig").SingleCommandBuffer;

pub const TransferContext = struct {
    pub fn transfer_image(target: *Image, final_layout: vk.ImageLayout, data: []u8) void {
        var staging_buffer: Buffer = undefined;
        staging_buffer.init(data.len, .{ .transfer_src_bit = true }, .sequential);
        defer staging_buffer.destroy();

        @memcpy(@ptrCast([*]u8, staging_buffer.allocation.mapped_memory), data.ptr, data.len);

        var scb: SingleCommandBuffer = SingleCommandBuffer.allocate(&rg.global_render_graph.command_pool) catch unreachable;
        scb.command_buffer.beginSingleTimeCommands();

        target.transitionImageLayout(scb.command_buffer.vk_ref, .transfer_dst_optimal);

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

        vkfn.d.cmdCopyBufferToImage(
            scb.command_buffer.vk_ref,
            staging_buffer.vk_ref,
            target.vk_ref,
            .transfer_dst_optimal,
            1,
            @ptrCast([*]const vk.BufferImageCopy, &region),
        );

        target.transitionImageLayout(scb.command_buffer.vk_ref, final_layout);

        scb.command_buffer.endSingleTimeCommands();
        scb.submit(vkctxt.graphics_queue);
    }

    pub fn transfer_buffer(target: *Buffer, data: []u8) void {
        var staging_buffer: Buffer = undefined;
        staging_buffer.init(data.len, .{ .transfer_src_bit = true }, .sequential);
        defer staging_buffer.destroy();

        @memcpy(@ptrCast([*]u8, staging_buffer.allocation.mapped_memory), data.ptr, data.len);

        var scb: SingleCommandBuffer = SingleCommandBuffer.allocate(&rg.global_render_graph.command_pool) catch unreachable;
        scb.command_buffer.beginSingleTimeCommands();

        const copy: vk.BufferCopy = .{
            .dst_offset = 0,
            .src_offset = 0,
            .size = data.len,
        };

        vkfn.d.cmdCopyBuffer(
            scb.command_buffer.vk_ref,
            staging_buffer.vk_ref,
            target.vk_ref,
            1,
            @ptrCast([*]const vk.BufferCopy, &copy),
        );

        scb.command_buffer.endSingleTimeCommands();
        scb.submit(vkctxt.graphics_queue);
    }
};
