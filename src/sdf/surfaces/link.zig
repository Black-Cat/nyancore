pub const Data = struct {
    length: f32,
    inner_radius: f32,
    outer_radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};
