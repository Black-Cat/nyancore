const std = @import("std");

pub const IterationContext = struct {
    pub const StackInfo = struct {
        index: usize,
        material: i32, // Negative indexes are used for generated materials
    };

    value_indexes: std.ArrayList(StackInfo),
    last_value_set_index: usize,
    any_value_set: bool,

    points: std.ArrayList([]const u8),
    cur_point_name: []const u8,

    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator) IterationContext {
        var cntx: IterationContext = .{
            .allocator = allocator,

            .value_indexes = std.ArrayList(StackInfo).init(allocator),
            .last_value_set_index = undefined,
            .any_value_set = false,

            .points = std.ArrayList([]const u8).init(allocator),
            .cur_point_name = undefined,
        };

        cntx.pushPointName("p");

        return cntx;
    }

    pub fn destroy(self: *IterationContext) void {
        self.value_indexes.deinit();
        self.points.deinit();
    }

    pub fn pushPointName(self: *IterationContext, name: []const u8) void {
        self.points.append(name) catch unreachable;
        self.cur_point_name = name;
    }

    pub fn popPointName(self: *IterationContext) void {
        self.allocator.free(self.cur_point_name);
        _ = self.points.pop();
        self.cur_point_name = self.points.items[self.points.items.len - 1];
    }

    pub fn pushStackInfo(self: *IterationContext, index: usize, material: i32) void {
        self.value_indexes.append(.{ .index = index, .material = material }) catch unreachable;

        self.last_value_set_index = index;
        self.any_value_set = true;
    }

    pub fn dropPreviousValueIndexes(self: *IterationContext, enter_index: usize) void {
        self.value_indexes.resize(enter_index + 1) catch unreachable;

        const info: StackInfo = self.value_indexes.items[enter_index];
        self.last_value_set_index = info.index;
    }
};
