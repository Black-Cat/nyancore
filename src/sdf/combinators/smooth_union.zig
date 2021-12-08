pub const Data = struct {
    smoothing: f32,

    mats: [2]i32,
    dist_indexes: [2]usize,
    enter_index: usize,
    enter_stack: usize,
};
