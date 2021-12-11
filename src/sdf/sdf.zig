const std = @import("std");
pub const SdfInfo = @import("sdf_info.zig").SdfInfo;

// Combinators
pub const Intersection = @import("combinators/intersection.zig").info;
pub const SmoothIntersection = @import("combinators/smooth_intersection.zig").info;
pub const SmoothSubtraction = @import("combinators/smooth_subtraction.zig").info;
pub const SmoothUnion = @import("combinators/smooth_union.zig").info;
pub const Subtraction = @import("combinators/subtraction.zig").info;
pub const Union = @import("combinators/union.zig").info;

// Materials
pub const CustomMaterial = @import("materials/custom_material.zig").info;
pub const Lambert = @import("materials/lambert.zig").info;
pub const OrenNayar = @import("materials/oren_nayar.zig").info;

// Modifiers
pub const Bend = @import("modifiers/bend.zig").info;
pub const Displacement = @import("modifiers/displacement.zig").info;
pub const DisplacementNoise = @import("modifiers/displacement_noise.zig").info;
pub const Elongate = @import("modifiers/elongate.zig").info;
pub const FiniteRepetition = @import("modifiers/finite_repetition.zig").info;
pub const InfiniteRepetition = @import("modifiers/infinite_repetition.zig").info;
pub const Onion = @import("modifiers/onion.zig").info;
pub const Rounding = @import("modifiers/rounding.zig").info;
pub const Scale = @import("modifiers/scale.zig").info;
pub const Symmetry = @import("modifiers/symmetry.zig").info;
pub const Transform = @import("modifiers/transform.zig").info;
pub const Twist = @import("modifiers/twist.zig").info;

// Custom
pub const CustomNode = @import("special/custom_node.zig").info;

pub const BoundingBox = @import("surfaces/bounding_box.zig").info;
pub const Box = @import("surfaces/box.zig").info;
pub const CappedCone = @import("surfaces/capped_cone.zig").info;
pub const CappedCylinder = @import("surfaces/capped_cylinder.zig").info;
pub const CappedTorus = @import("surfaces/capped_torus.zig").info;
pub const Capsule = @import("surfaces/capsule.zig").info;
pub const Cone = @import("surfaces/cone.zig").info;
pub const Ellipsoid = @import("surfaces/ellipsoid.zig").info;
pub const HexagonalPrism = @import("surfaces/hexagonal_prism.zig").info;
pub const InfiniteCone = @import("surfaces/infinite_cone.zig").info;
pub const InfiniteCylinder = @import("surfaces/infinite_cylinder.zig").info;
pub const Link = @import("surfaces/link.zig").info;
pub const Octahedron = @import("surfaces/octahedron.zig").info;
pub const Plane = @import("surfaces/plane.zig").info;
pub const Pyramid = @import("surfaces/pyramid.zig").info;
pub const Quad = @import("surfaces/quad.zig").info;
pub const Rhombus = @import("surfaces/rhombus.zig").info;
pub const RoundBox = @import("surfaces/round_box.zig").info;
pub const RoundCone = @import("surfaces/round_cone.zig").info;
pub const RoundedCylinder = @import("surfaces/rounded_cylinder.zig").info;
pub const SolidAngle = @import("surfaces/solid_angle.zig").info;
pub const Sphere = @import("surfaces/sphere.zig").info;
pub const Torus = @import("surfaces/torus.zig").info;
pub const Triangle = @import("surfaces/triangle.zig").info;
pub const TriangularPrism = @import("surfaces/triangular_prism.zig").info;
pub const VerticalCappedCone = @import("surfaces/vertical_capped_cone.zig").info;
pub const VerticalCappedCylinder = @import("surfaces/vertical_capped_cylinder.zig").info;
pub const VerticalCapsule = @import("surfaces/vertical_capsule.zig").info;
pub const VerticalRoundCone = @import("surfaces/vertical_round_cone.zig").info;

const all_node_types = [_]SdfInfo{
    Intersection,
    SmoothIntersection,
    SmoothSubtraction,
    SmoothUnion,
    Subtraction,
    Union,

    CustomMaterial,
    Lambert,
    OrenNayar,

    Bend,
    Displacement,
    DisplacementNoise,
    Elongate,
    FiniteRepetition,
    InfiniteRepetition,
    Onion,
    Rounding,
    Scale,
    Symmetry,
    Transform,
    Twist,

    CustomNode,

    BoundingBox,
    Box,
    CappedCone,
    CappedCylinder,
    CappedTorus,
    Capsule,
    Cone,
    Ellipsoid,
    HexagonalPrism,
    InfiniteCone,
    InfiniteCylinder,
    Link,
    Octahedron,
    Plane,
    Pyramid,
    Quad,
    Rhombus,
    RoundBox,
    RoundCone,
    RoundedCylinder,
    SolidAngle,
    Sphere,
    Torus,
    Triangle,
    TriangularPrism,
    VerticalCappedCone,
    VerticalCappedCylinder,
    VerticalCapsule,
    VerticalRoundCone,
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
