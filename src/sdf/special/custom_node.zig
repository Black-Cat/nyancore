pub const Data = struct {
    pub const max_func_len: usize = 1024;
    enter_function: [max_func_len]u8,
    exit_function: [max_func_len]u8,

    enter_stack: usize,
    enter_index: usize,
};
