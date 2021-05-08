const Allocator = std.mem.Allocator;
const std = @import("std");

pub const Config = struct {
    allocator: *Allocator,
    appname: []const u8,
    map: std.AutoHashMap([]const u8, []const u8),

    pub fn init(allocator: *Allocator, appname: []const u8) Config {
        return Config{
            .allocator = allocator,
            .appname = appname,
            .map = std.AutoHashMap([]const u8, []const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Config) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value);
        }

        self.map.deinit();
    }

    pub fn loadConfig(self: *Config, config_file: []const u8) !void {
        const dir_path: []const u8 = try std.fs.getAppDataDir(self.allocator, self.appname);
        defer self.allocator.free(dir_path);

        std.fs.makeDirAbsolute(dir_path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        const config_path: []const u8 = std.fs.path.join(self.allocator, &[_][]const u8{ dir_path, config_file }) catch unreachable;
        defer self.allocator.free(config_path);

        const file: std.fs.File = try std.fs.createFileAbsolute(config_path, .{ .read = true, .truncate = false });
        defer file.close();

        try self.parseConfig(file);
    }

    fn parseConfig(self: *Config, config_file: std.fs.File) !void {
        const reader: std.fs.File.Reader = config_file.reader();

        var buffer: [1024]u8 = undefined;
        var groupBuffer: [512]u8 = undefined;
        var groupLen: usize = 0;
        while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
            if (line[0] == '[') {
                std.mem.copy(u8, &groupBuffer, line[1..(line.len - 1)]);
                groupLen = line.len - 1;
                groupBuffer[groupLen - 1] = '_';
                continue;
            }

            var it: std.mem.SplitIterator = std.mem.split(line, "=");
            const name: []const u8 = it.next() orelse continue;
            const value: []const u8 = it.rest();
            std.mem.copy(u8, groupBuffer[groupLen..], name);

            const nameDupe: []const u8 = try self.allocator.dupe(u8, groupBuffer[0..(groupLen + name.len)]);
            const valueDupe: []const u8 = try self.allocator.dupe(u8, value);

            try self.map.putNoClobber(nameDupe, valueDupe);
        }
    }
};

test "load config" {
    var config: Config = Config.init(std.testing.allocator, "nyancore");
    defer config.deinit();

    try config.loadConfig("test.conf");

    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n", .{});

    var it = config.map.iterator();
    while (it.next()) |entry| {
        try stdout.print("{}\n", .{entry});
    }
}
