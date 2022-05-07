const std = @import("std");
pub const SdfInfo = @import("sdf_info.zig").SdfInfo;
pub const appendNoMatCheck = @import("sdf_info.zig").appendNoMatCheck;
pub const IterationContext = @import("iteration_context.zig").IterationContext;
pub const Templates = @import("shader_templates.zig");

pub const EnterCommandFn = fn (ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8;
pub const ExitCommandFn = fn (ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8;
pub const AppendMatCheckFn = fn (exit_command: []const u8, buffer: *[]u8, mat_offset: usize, alloc: std.mem.Allocator) []const u8;

// Combinators
pub const Intersection = @import("combinators/intersection.zig");
pub const SmoothIntersection = @import("combinators/smooth_intersection.zig");
pub const SmoothSubtraction = @import("combinators/smooth_subtraction.zig");
pub const SmoothUnion = @import("combinators/smooth_union.zig");
pub const Subtraction = @import("combinators/subtraction.zig");
pub const Union = @import("combinators/union.zig");

// Materials
pub const CustomMaterial = @import("materials/custom_material.zig");
pub const Discard = @import("materials/discard.zig");
pub const Lambert = @import("materials/lambert.zig");
pub const OrenNayar = @import("materials/oren_nayar.zig");

// Modifiers
pub const Bend = @import("modifiers/bend.zig");
pub const Displacement = @import("modifiers/displacement.zig");
pub const DisplacementNoise = @import("modifiers/displacement_noise.zig");
pub const Elongate = @import("modifiers/elongate.zig");
pub const FiniteRepetition = @import("modifiers/finite_repetition.zig");
pub const InfiniteRepetition = @import("modifiers/infinite_repetition.zig");
pub const Onion = @import("modifiers/onion.zig");
pub const Rounding = @import("modifiers/rounding.zig");
pub const Scale = @import("modifiers/scale.zig");
pub const Symmetry = @import("modifiers/symmetry.zig");
pub const Transform = @import("modifiers/transform.zig");
pub const Twist = @import("modifiers/twist.zig");
pub const Wrinkles = @import("modifiers/wrinkles.zig");

// Custom
pub const CustomNode = @import("special/custom_node.zig");

// Surfaces
pub const BezierCurve = @import("surfaces/bezier_curve.zig");
pub const BoundingBox = @import("surfaces/bounding_box.zig");
pub const Box = @import("surfaces/box.zig");
pub const CappedCone = @import("surfaces/capped_cone.zig");
pub const CappedCylinder = @import("surfaces/capped_cylinder.zig");
pub const CappedTorus = @import("surfaces/capped_torus.zig");
pub const Capsule = @import("surfaces/capsule.zig");
pub const Cone = @import("surfaces/cone.zig");
pub const Ellipsoid = @import("surfaces/ellipsoid.zig");
pub const HexagonalPrism = @import("surfaces/hexagonal_prism.zig");
pub const InfiniteCone = @import("surfaces/infinite_cone.zig");
pub const InfiniteCylinder = @import("surfaces/infinite_cylinder.zig");
pub const Link = @import("surfaces/link.zig");
pub const Octahedron = @import("surfaces/octahedron.zig");
pub const Plane = @import("surfaces/plane.zig");
pub const Pyramid = @import("surfaces/pyramid.zig");
pub const Quad = @import("surfaces/quad.zig");
pub const Rhombus = @import("surfaces/rhombus.zig");
pub const RoundBox = @import("surfaces/round_box.zig");
pub const RoundCone = @import("surfaces/round_cone.zig");
pub const RoundedCylinder = @import("surfaces/rounded_cylinder.zig");
pub const SolidAngle = @import("surfaces/solid_angle.zig");
pub const Sphere = @import("surfaces/sphere.zig");
pub const Torus = @import("surfaces/torus.zig");
pub const Triangle = @import("surfaces/triangle.zig");
pub const TriangularPrism = @import("surfaces/triangular_prism.zig");
pub const VerticalCappedCone = @import("surfaces/vertical_capped_cone.zig");
pub const VerticalCappedCylinder = @import("surfaces/vertical_capped_cylinder.zig");
pub const VerticalCapsule = @import("surfaces/vertical_capsule.zig");
pub const VerticalRoundCone = @import("surfaces/vertical_round_cone.zig");

const all_node_types = [_]SdfInfo{
    Intersection.info,
    SmoothIntersection.info,
    SmoothSubtraction.info,
    SmoothUnion.info,
    Subtraction.info,
    Union.info,

    CustomMaterial.info,
    Discard.info,
    Lambert.info,
    OrenNayar.info,

    Bend.info,
    Displacement.info,
    DisplacementNoise.info,
    Elongate.info,
    FiniteRepetition.info,
    InfiniteRepetition.info,
    Onion.info,
    Rounding.info,
    Scale.info,
    Symmetry.info,
    Transform.info,
    Twist.info,
    Wrinkles.info,

    CustomNode.info,

    BezierCurve.info,
    BoundingBox.info,
    Box.info,
    CappedCone.info,
    CappedCylinder.info,
    CappedTorus.info,
    Capsule.info,
    Cone.info,
    Ellipsoid.info,
    HexagonalPrism.info,
    InfiniteCone.info,
    InfiniteCylinder.info,
    Link.info,
    Octahedron.info,
    Plane.info,
    Pyramid.info,
    Quad.info,
    Rhombus.info,
    RoundBox.info,
    RoundCone.info,
    RoundedCylinder.info,
    SolidAngle.info,
    Sphere.info,
    Torus.info,
    Triangle.info,
    TriangularPrism.info,
    VerticalCappedCone.info,
    VerticalCappedCylinder.info,
    VerticalCapsule.info,
    VerticalRoundCone.info,
};

const SdfKV = struct {
    @"0": []const u8,
    @"1": *const SdfInfo,
};

fn collectToKV(comptime collection: []const SdfInfo) []SdfKV {
    var kvs = [1]SdfKV{undefined} ** collection.len;
    for (collection) |*sdf_info, i|
        kvs[i] = .{ .@"0" = sdf_info.name, .@"1" = sdf_info };
    return kvs[0..];
}

pub const node_map = std.ComptimeStringMap(
    *const SdfInfo,
    collectToKV(all_node_types[0..]),
);
