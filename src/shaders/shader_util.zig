const std = @import("std");
const vk = @import("../vk.zig");
const c = struct {
    usingnamespace @cImport({
        @cInclude("glslang_c_interface.h");
    });
};
const vkctxt = @import("../vulkan_wrapper/vulkan_context.zig");

const printError = @import("../application/print_error.zig").printError;
const printErrorNoPanic = @import("../application/print_error.zig").printErrorNoPanic;

pub const ShaderStage = enum {
    vertex,
    fragment,
    compute,
};

const default_resources: c.glslang_resource_s = .{
    .max_lights = 32,
    .max_clip_planes = 6,
    .max_texture_units = 32,
    .max_texture_coords = 32,
    .max_vertex_attribs = 64,
    .max_vertex_uniform_components = 4096,
    .max_varying_floats = 64,
    .max_vertex_texture_image_units = 32,
    .max_combined_texture_image_units = 80,
    .max_texture_image_units = 32,
    .max_fragment_uniform_components = 4096,
    .max_draw_buffers = 32,
    .max_vertex_uniform_vectors = 128,
    .max_varying_vectors = 8,
    .max_fragment_uniform_vectors = 16,
    .max_vertex_output_vectors = 16,
    .max_fragment_input_vectors = 15,
    .min_program_texel_offset = -8,
    .max_program_texel_offset = 7,
    .max_clip_distances = 8,
    .max_compute_work_group_count_x = 65535,
    .max_compute_work_group_count_y = 65535,
    .max_compute_work_group_count_z = 65535,
    .max_compute_work_group_size_x = 1024,
    .max_compute_work_group_size_y = 1024,
    .max_compute_work_group_size_z = 64,
    .max_compute_uniform_components = 1024,
    .max_compute_texture_image_units = 16,
    .max_compute_image_uniforms = 8,
    .max_compute_atomic_counters = 8,
    .max_compute_atomic_counter_buffers = 1,
    .max_varying_components = 60,
    .max_vertex_output_components = 64,
    .max_geometry_input_components = 64,
    .max_geometry_output_components = 128,
    .max_fragment_input_components = 128,
    .max_image_units = 8,
    .max_combined_image_units_and_fragment_outputs = 8,
    .max_combined_shader_output_resources = 8,
    .max_image_samples = 0,
    .max_vertex_image_uniforms = 0,
    .max_tess_control_image_uniforms = 0,
    .max_tess_evaluation_image_uniforms = 0,
    .max_geometry_image_uniforms = 0,
    .max_fragment_image_uniforms = 8,
    .max_combined_image_uniforms = 8,
    .max_geometry_texture_image_units = 16,
    .max_geometry_output_vertices = 256,
    .max_geometry_total_output_components = 1024,
    .max_geometry_uniform_components = 1024,
    .max_geometry_varying_components = 64,
    .max_tess_control_input_components = 128,
    .max_tess_control_output_components = 128,
    .max_tess_control_texture_image_units = 16,
    .max_tess_control_uniform_components = 1024,
    .max_tess_control_total_output_components = 4096,
    .max_tess_evaluation_input_components = 128,
    .max_tess_evaluation_output_components = 128,
    .max_tess_evaluation_texture_image_units = 16,
    .max_tess_evaluation_uniform_components = 1024,
    .max_tess_patch_components = 120,
    .max_patch_vertices = 32,
    .max_tess_gen_level = 64,
    .max_viewports = 16,
    .max_vertex_atomic_counters = 0,
    .max_tess_control_atomic_counters = 0,
    .max_tess_evaluation_atomic_counters = 0,
    .max_geometry_atomic_counters = 0,
    .max_fragment_atomic_counters = 8,
    .max_combined_atomic_counters = 8,
    .max_atomic_counter_bindings = 1,
    .max_vertex_atomic_counter_buffers = 0,
    .max_tess_control_atomic_counter_buffers = 0,
    .max_tess_evaluation_atomic_counter_buffers = 0,
    .max_geometry_atomic_counter_buffers = 0,
    .max_fragment_atomic_counter_buffers = 1,
    .max_combined_atomic_counter_buffers = 1,
    .max_atomic_counter_buffer_size = 16384,
    .max_transform_feedback_buffers = 4,
    .max_transform_feedback_interleaved_components = 64,
    .max_cull_distances = 8,
    .max_combined_clip_and_cull_distances = 8,
    .max_samples = 4,
    .max_mesh_output_vertices_nv = 256,
    .max_mesh_output_primitives_nv = 512,
    .max_mesh_work_group_size_x_nv = 32,
    .max_mesh_work_group_size_y_nv = 1,
    .max_mesh_work_group_size_z_nv = 1,
    .max_task_work_group_size_x_nv = 32,
    .max_task_work_group_size_y_nv = 1,
    .max_task_work_group_size_z_nv = 1,
    .max_mesh_view_count_nv = 4,
    .maxDualSourceDrawBuffersEXT = 1,

    .limits = .{
        .non_inductive_for_loops = true,
        .while_loops = true,
        .do_while_loops = true,
        .general_uniform_indexing = true,
        .general_attribute_matrix_vector_indexing = true,
        .general_varying_indexing = true,
        .general_sampler_indexing = true,
        .general_variable_indexing = true,
        .general_constant_matrix_vector_indexing = true,
    },
};

var input: c.glslang_input_t = .{
    .language = c.GLSLANG_SOURCE_GLSL,
    .client = c.GLSLANG_CLIENT_VULKAN,
    .client_version = c.GLSLANG_TARGET_VULKAN_1_2,
    .target_language = c.GLSLANG_TARGET_SPV,
    .target_language_version = c.GLSLANG_TARGET_SPV_1_0,
    .default_version = 100,
    .default_profile = c.GLSLANG_NO_PROFILE,
    .force_default_version_and_profile = 0,
    .forward_compatible = 0,
    .messages = c.GLSLANG_MSG_DEFAULT_BIT,
    .resource = &default_resources,

    .stage = undefined,
    .code = undefined,
};

fn printGlslangError(err_message: [*c]const u8) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("\x1b[1;31mGLSLANG ERROR:\x1b[0m {s}\n", .{err_message}) catch unreachable;
}

fn reportGlslangError(shader: *c.glslang_shader_t, message: []const u8) void {
    printGlslangError(c.glslang_shader_get_info_log(shader));
    printGlslangError(c.glslang_shader_get_info_debug_log(shader));
    printError("glslang", message);
}

pub const CompiledShader = struct {
    size: usize,
    pcode: [*]c_uint,
};

pub fn initShaderCompilation() void {
    _ = c.glslang_initialize_process();
}

pub fn compileShader(code: [*:0]const u8, stage: ShaderStage) CompiledShader {
    input.code = code;
    input.stage = switch (stage) {
        .vertex => c.GLSLANG_STAGE_VERTEX,
        .fragment => c.GLSLANG_STAGE_FRAGMENT,
        .compute => c.GLSLANG_STAGE_COMPUTE,
    };

    var shader: *c.glslang_shader_t = c.glslang_shader_create(&input) orelse unreachable;

    if (c.glslang_shader_preprocess(shader, &input) != 1)
        reportGlslangError(shader, "Can't preprocess shader");

    if (c.glslang_shader_parse(shader, &input) != 1)
        reportGlslangError(shader, "Can't parse shader");

    var program: *c.glslang_program_t = c.glslang_program_create() orelse unreachable;
    c.glslang_program_add_shader(program, shader);

    if (c.glslang_program_link(program, c.GLSLANG_MSG_SPV_RULES_BIT | c.GLSLANG_MSG_VULKAN_RULES_BIT) != 1)
        reportGlslangError(shader, "Can't link program");

    c.glslang_program_SPIRV_generate(program, input.stage);

    var messages = c.glslang_program_SPIRV_get_messages(program);
    if (messages != null)
        printGlslangError(messages);

    c.glslang_shader_delete(shader);

    var compiledShader: CompiledShader = undefined;
    compiledShader.size = c.glslang_program_SPIRV_get_size(program) * @sizeOf(c_uint);
    compiledShader.pcode = c.glslang_program_SPIRV_get_ptr(program);

    return compiledShader;
}

pub fn loadShader(shader_code: [*:0]const u8, stage: ShaderStage) vk.ShaderModule {
    const shader: CompiledShader = compileShader(shader_code, stage);

    const module_create_info: vk.ShaderModuleCreateInfo = .{
        .code_size = shader.size,
        .p_code = shader.pcode,
        .flags = .{},
    };

    var shader_module: vk.ShaderModule = vkctxt.vkd.createShaderModule(vkctxt.vkc.device, module_create_info, null) catch |err| {
        vkctxt.printVulkanError("Can't create shader module", err, vkctxt.vkc.allocator);
        @panic("Can't create shader module");
    };

    return shader_module;
}
