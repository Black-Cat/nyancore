const std = @import("std");

const rg = @import("../render_graph.zig");
const vk = @import("../../../vk.zig");
const nm = @import("../../../math/math.zig");

const vkctxt = @import("../../../vulkan_wrapper/vulkan_context.zig");
const vkfn = @import("../../../vulkan_wrapper/vulkan_functions.zig");

const RGPass = @import("../render_graph_pass.zig").RGPass;
const RGResource = @import("../render_graph_resource.zig").RGResource;

const Camera = @import("../../../tools/mesh_viewer/camera.zig").Camera;
const CommandBuffer = @import("../../../vulkan_wrapper/command_buffer.zig").CommandBuffer;
const DescriptorPool = @import("../../../vulkan_wrapper/descriptor_pool.zig").DescriptorPool;
const DescriptorSetLayout = @import("../../../vulkan_wrapper/descriptor_set_layout.zig").DescriptorSetLayout;
const DescriptorSets = @import("../../../vulkan_wrapper/descriptor_sets.zig").DescriptorSets;
const ImageView = @import("../../../vulkan_wrapper/image_view.zig").ImageView;
const Mesh = @import("../../../vulkan_wrapper/mesh.zig").Mesh;
const Pipeline = @import("../../../vulkan_wrapper/pipeline.zig").Pipeline;
const PipelineBuilder = @import("../../../vulkan_wrapper/pipeline_builder.zig").PipelineBuilder;
const PipelineCache = @import("../../../vulkan_wrapper/pipeline_cache.zig").PipelineCache;
const RenderPass = @import("../../../vulkan_wrapper/render_pass.zig").RenderPass;
const ShaderModule = @import("../../../vulkan_wrapper/shader_module.zig").ShaderModule;

const DynamicBuffer = @import("../resources/dynamic_buffer.zig").DynamicBuffer;
const ImageWithView = @import("../resources/image_with_view.zig").ImageWithView;
const Material = @import("../resources/material.zig").Material;
const MaterialSignature = @import("../resources/material_signature.zig").MaterialSignature;
const RenderObject = @import("../resources/render_object.zig").RenderObject;
const StorageBuffer = @import("../resources/storage_buffer.zig").StorageBuffer;

const Model = @import("../../../model/model.zig").Model;

const printVulkanError = @import("../../../vulkan_wrapper/print_vulkan_error.zig").printVulkanError;

const CameraData = struct {
    view_proj: nm.mat4x4,
};

const SceneData = struct {
    light_dir: nm.vec3,
};

const ObjectData = struct {
    transform: nm.mat4x4,
};

pub fn MeshPass(comptime TargetType: type) type {
    return struct {
        const SelfType = MeshPass(TargetType);

        const max_object_count: comptime_int = 10000;

        rg_pass: RGPass,

        render_pass: RenderPass,
        target: *TargetType,

        vert_shader: ShaderModule,
        frag_shader: ShaderModule,

        pipeline_cache: PipelineCache,

        mesh: Mesh,
        camera: *Camera,

        depth_buffer: *ImageWithView,

        time: f32, // Temporary

        camera_buffer: DynamicBuffer(CameraData),
        scene_buffer: DynamicBuffer(SceneData),
        object_buffer: StorageBuffer(ObjectData),

        descriptor_pool: DescriptorPool,

        descriptor_set_layout: DescriptorSetLayout,
        descriptor_sets: DescriptorSets,

        objects_descriptor_set_layout: DescriptorSetLayout,
        objects_descriptor_sets: DescriptorSets,

        signature_materials_map: std.AutoArrayHashMap(u32, *Material),
        material_render_objects_map: std.AutoArrayHashMap(*Material, *std.ArrayList(RenderObject)),

        // Accepts *ViewportTexture or *Swapchain as target
        pub fn init(
            self: *SelfType,
            comptime name: []const u8,
            target: *TargetType,
            depth_buffer: *ImageWithView,
            camera: *Camera,
        ) void {
            const res: *RGResource = rg.global_render_graph.getResource(target);

            self.rg_pass.init(name, rg.global_render_graph.allocator, passInit, passDeinit, passRender);
            self.rg_pass.appendWriteResource(res);
            self.rg_pass.appendWriteResource(rg.global_render_graph.getResource(depth_buffer));

            self.target = target;
            self.camera = camera;
            self.depth_buffer = depth_buffer;

            self.rg_pass.pipeline_start = .{ .vertex_input_bit = true };
            self.rg_pass.pipeline_end = .{ .color_attachment_output_bit = true };

            self.signature_materials_map = @TypeOf(self.signature_materials_map).init(vkctxt.allocator);
            self.material_render_objects_map = @TypeOf(self.material_render_objects_map).init(vkctxt.allocator);

            self.time = 0.0;
        }

        pub fn deinit(self: *SelfType) void {
            for (self.signature_materials_map.values()) |mat| {
                mat.deinit();
                vkctxt.allocator.destroy(mat);
            }
            self.signature_materials_map.deinit();

            for (self.material_render_objects_map.values()) |list| {
                for (list.items) |ro|
                    ro.deinit();
                list.deinit();
                vkctxt.allocator.destroy(list);
            }
            self.material_render_objects_map.deinit();
        }

        pub fn setModels(self: *SelfType, models: []Model) void {
            for (models) |*m| {
                const ms: MaterialSignature = MaterialSignature.createFromModel(m);
                const ms_int: u32 = ms.toInt();

                if (!self.signature_materials_map.contains(ms_int)) {
                    var mat: *Material = vkctxt.allocator.create(Material) catch unreachable;
                    mat.* = self.createMaterial(m);
                    self.signature_materials_map.put(ms_int, mat) catch unreachable;

                    var list: *std.ArrayList(RenderObject) = vkctxt.allocator.create(std.ArrayList(RenderObject)) catch unreachable;
                    list.* = std.ArrayList(RenderObject).init(vkctxt.allocator);
                    self.material_render_objects_map.put(mat, list) catch unreachable;
                }

                const mat: *Material = self.signature_materials_map.get(ms_int).?;
                const list: *std.ArrayList(RenderObject) = self.material_render_objects_map.get(mat).?;

                const ro: *RenderObject = list.addOne() catch unreachable;
                ro.initFromModel(m);
            }
        }

        fn passInit(rg_pass: *RGPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", rg_pass);

            const vert_code = @embedFile("mesh_pass.vert");
            self.vert_shader = ShaderModule.load(vert_code, .vertex);

            const frag_code = @embedFile("mesh_pass.frag");
            self.frag_shader = ShaderModule.load(frag_code, .fragment);

            var attachments: [2]vk.AttachmentDescription = self.getAttachmentsDescriptions();
            var views: [1]ImageView = self.getImageViews();

            self.render_pass.init(self.target, views[0..], attachments[0..]);
            self.render_pass.target_recreated_callback = targetRecreatedCallback;

            self.pipeline_cache = PipelineCache.createEmpty();

            self.camera_buffer.init();
            self.scene_buffer.init();
            self.object_buffer.init(max_object_count);

            const pool_sizes = &[_]vk.DescriptorPoolSize{
                .{ .type = .uniform_buffer_dynamic, .descriptor_count = 2 },
                .{ .type = .storage_buffer, .descriptor_count = 1 },
            };
            self.descriptor_pool.init(pool_sizes[0..], rg.global_render_graph.in_flight * 2);

            const camera_bindings: vk.DescriptorSetLayoutBinding = .{
                .stage_flags = .{ .vertex_bit = true },
                .binding = 0,
                .descriptor_count = 1,
                .descriptor_type = .uniform_buffer_dynamic,
                .p_immutable_samplers = undefined,
            };

            const scene_bindings: vk.DescriptorSetLayoutBinding = .{
                .stage_flags = .{ .fragment_bit = true },
                .binding = 1,
                .descriptor_count = 1,
                .descriptor_type = .uniform_buffer_dynamic,
                .p_immutable_samplers = undefined,
            };

            const object_bindings: vk.DescriptorSetLayoutBinding = .{
                .stage_flags = .{ .vertex_bit = true },
                .binding = 0,
                .descriptor_count = 1,
                .descriptor_type = .storage_buffer,
                .p_immutable_samplers = undefined,
            };

            self.descriptor_set_layout.init(&.{ camera_bindings, scene_bindings });
            self.objects_descriptor_set_layout.init(&.{object_bindings});

            self.descriptor_sets.init(
                &self.descriptor_pool,
                &.{self.descriptor_set_layout.vk_ref},
                @intCast(usize, rg.global_render_graph.in_flight),
            );
            self.objects_descriptor_sets.init(
                &self.descriptor_pool,
                &.{self.objects_descriptor_set_layout.vk_ref},
                @intCast(usize, rg.global_render_graph.in_flight),
            );

            self.descriptor_sets.writeBufferAll(0, .uniform_buffer_dynamic, &[_]vk.DescriptorBufferInfo{
                .{
                    .buffer = self.camera_buffer.buffer.vk_ref,
                    .offset = 0,
                    .range = @sizeOf(CameraData),
                },
            });
            self.descriptor_sets.writeBufferAll(1, .uniform_buffer_dynamic, &[_]vk.DescriptorBufferInfo{
                .{
                    .buffer = self.scene_buffer.buffer.vk_ref,
                    .offset = 0,
                    .range = @sizeOf(SceneData),
                },
            });

            for (self.object_buffer.buffers) |b, ind|
                DescriptorSets.writeBuffer(self.objects_descriptor_sets.vk_ref[ind], 0, .storage_buffer, &[_]vk.DescriptorBufferInfo{
                    .{
                        .buffer = b.vk_ref,
                        .offset = 0,
                        .range = @sizeOf(ObjectData) * max_object_count,
                    },
                });
        }

        fn passDeinit(render_pass: *RGPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", render_pass);

            self.camera_buffer.deinit();
            self.scene_buffer.deinit();

            self.descriptor_sets.deinit();
            self.descriptor_set_layout.deinit();
            self.descriptor_pool.deinit();

            self.render_pass.destroy();

            self.pipeline_cache.destroy();

            self.vert_shader.destroy();
            self.frag_shader.destroy();
        }

        fn passRender(render_pass: *RGPass, command_buffer: *CommandBuffer, frame_index: u32) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "rg_pass", render_pass);

            // Temporary place to update light pos
            const io: *@import("../../../c.zig").ImGuiIO = @import("../../../c.zig").igGetIO();
            const delta: f32 = io.DeltaTime;
            self.time += delta;
            if (self.time > 2.0 * 3.14)
                self.time -= 2.0 * 3.14;
            self.scene_buffer.data[frame_index].light_dir = .{ std.math.sin(self.time), 1.0, std.math.cos(self.time) };

            const clear_color: [2]vk.ClearValue = .{
                .{ .color = .{ .float_32 = [_]f32{ 0.6, 0.3, 0.6, 1.0 } } },
                .{ .depth_stencil = .{ .depth = 1.0, .stencil = 0.0 } },
            };
            const render_pass_info: vk.RenderPassBeginInfo = .{
                .render_pass = self.render_pass.vk_ref,
                .framebuffer = self.render_pass.getCurrentFramebuffer().vk_ref,
                .render_area = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = self.target.image_extent,
                },
                .clear_value_count = @intCast(u32, clear_color.len),
                .p_clear_values = @ptrCast([*]const vk.ClearValue, &clear_color[0]),
            };

            vkfn.d.cmdBeginRenderPass(command_buffer.vk_ref, render_pass_info, .@"inline");
            defer vkfn.d.cmdEndRenderPass(command_buffer.vk_ref);

            if (self.material_render_objects_map.count() == 0) return;

            const viewport_info: vk.Viewport = .{
                .width = @intToFloat(f32, self.target.image_extent.width),
                .height = @intToFloat(f32, self.target.image_extent.height),
                .min_depth = 0.0,
                .max_depth = 1.0,
                .x = 0,
                .y = 0,
            };

            var scissor_rect: vk.Rect2D = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.target.image_extent,
            };
            const scissor_rect_ptr: *vk.Rect2D = &scissor_rect;

            self.camera_buffer.data[frame_index].view_proj = nm.Mat4x4.mul(
                self.camera.projectionFn(self.camera, nm.rad(60.0), viewport_info.width / viewport_info.height, 0.0001, 100.0),
                self.camera.viewMatrix(),
            );

            var object_instance: u32 = 0;
            var it = self.material_render_objects_map.iterator();
            while (it.next()) |kv| {
                const render_objects: *std.ArrayList(RenderObject) = kv.value_ptr.*;
                for (render_objects.items) |ro| {
                    self.object_buffer.data[frame_index][object_instance].transform = ro.transform;
                    object_instance += 1;
                }
            }

            object_instance = 0;
            it = self.material_render_objects_map.iterator();
            while (it.next()) |kv| {
                const mat: *Material = kv.key_ptr.*;
                const render_objects: *std.ArrayList(RenderObject) = kv.value_ptr.*;

                vkfn.d.cmdBindPipeline(command_buffer.vk_ref, .graphics, mat.pipeline.vk_ref);

                const offsets = [_]u32{
                    @intCast(u32, frame_index * self.camera_buffer.data_offset),
                    @intCast(u32, frame_index * self.scene_buffer.data_offset),
                };
                const descriptors = [_]vk.DescriptorSet{
                    self.descriptor_sets.vk_ref[frame_index],
                    self.objects_descriptor_sets.vk_ref[frame_index],
                };

                vkfn.d.cmdBindDescriptorSets(
                    command_buffer.vk_ref,
                    .graphics,
                    mat.pipeline_layout.vk_ref,
                    0,
                    @intCast(u32, descriptors.len),
                    @ptrCast([*]const vk.DescriptorSet, &descriptors),
                    @intCast(u32, offsets.len),
                    @ptrCast([*]const u32, &offsets),
                );

                vkfn.d.cmdSetViewport(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Viewport, &viewport_info));
                vkfn.d.cmdSetScissor(command_buffer.vk_ref, 0, 1, @ptrCast([*]const vk.Rect2D, scissor_rect_ptr));

                for (render_objects.items) |ro| {
                    ro.mesh.bind(command_buffer);
                    vkfn.d.cmdDrawIndexed(command_buffer.vk_ref, @intCast(u32, ro.mesh.index_count), 1, 0, 0, object_instance);
                    object_instance += 1;
                }
            }
        }

        fn targetRecreatedCallback(render_pass: *RenderPass) void {
            const self: *SelfType = @fieldParentPtr(SelfType, "render_pass", render_pass);

            const extent: vk.Extent3D = .{
                .width = self.target.image_extent.width,
                .height = self.target.image_extent.height,
                .depth = 1.0,
            };
            self.depth_buffer.resize(extent);

            var views: [1]ImageView = self.getImageViews();
            self.render_pass.recreateFramebuffers(self.target, views[0..]);
        }

        fn getAttachmentsDescriptions(self: *SelfType) [2]vk.AttachmentDescription {
            return .{
                .{
                    .format = self.target.image_format,
                    .samples = .{ .@"1_bit" = true },
                    .load_op = self.rg_pass.load_op,
                    .store_op = .store,
                    .stencil_load_op = .dont_care,
                    .stencil_store_op = .dont_care,
                    .initial_layout = self.rg_pass.initial_layout,
                    .final_layout = self.rg_pass.final_layout,
                    .flags = .{},
                },
                .{
                    .format = self.depth_buffer.image.format,
                    .samples = .{ .@"1_bit" = true },
                    .load_op = .clear,
                    .store_op = .store,
                    .stencil_load_op = .clear,
                    .stencil_store_op = .dont_care,
                    .initial_layout = .@"undefined",
                    .final_layout = .depth_stencil_attachment_optimal,
                    .flags = .{},
                },
            };
        }

        fn getImageViews(self: *SelfType) [1]ImageView {
            return .{self.depth_buffer.view};
        }

        fn createMaterial(self: *SelfType, model: *Model) Material {
            const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
                PipelineBuilder.buildShaderStageCreateInfo(.{ .vertex_bit = true }, &self.vert_shader),
                PipelineBuilder.buildShaderStageCreateInfo(.{ .fragment_bit = true }, &self.frag_shader),
            };

            const color_blend_attachments = [_]vk.PipelineColorBlendAttachmentState{
                PipelineBuilder.buildBlendAttachmentState(false),
            };

            var vertex_attributes = model.generateAttributeDescriptions(rg.global_render_graph.allocator);
            defer rg.global_render_graph.allocator.free(vertex_attributes);

            var material: Material = .{};
            material.init(
                shader_stages[0..],
                color_blend_attachments[0..],
                vertex_attributes,
                model.generateInputBindings(),
                &.{
                    self.descriptor_set_layout.vk_ref,
                    self.objects_descriptor_set_layout.vk_ref,
                },
                &self.pipeline_cache,
                &self.render_pass,
            );

            return material;
        }
    };
}
