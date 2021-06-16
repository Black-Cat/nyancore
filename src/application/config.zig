const Allocator = std.mem.Allocator;
const std = @import("std");

const BufMap = std.BufMap;
const Entry = std.StringHashMap([]const u8).Entry;

pub var global_config: Config = undefined;

pub const Config = struct {
    allocator: *Allocator,
    appname: []const u8,
    config_file: []const u8,
    map: BufMap,

    pub fn init(self: *Config, allocator: *Allocator, appname: []const u8, config_file: []const u8) void {
        self.allocator = allocator;
        self.appname = appname;
        self.config_file = config_file;
        self.map = BufMap.init(allocator);
    }

    pub fn deinit(self: *Config) void {
        self.map.deinit();
    }

    pub fn load(self: *Config) !void {
        const config_path: []const u8 = try self.getValidConfigFilePath();
        defer self.allocator.free(config_path);

        const file: std.fs.File = try std.fs.createFileAbsolute(config_path, .{ .read = true, .truncate = false });
        defer file.close();

        try self.parse(file);
    }

    pub fn flush(self: *Config) !void {
        const config_path: []const u8 = try self.getValidConfigFilePath();
        defer self.allocator.free(config_path);

        const file: std.fs.File = try std.fs.createFileAbsolute(config_path, .{ .read = false, .truncate = true });
        defer file.close();

        try self.write(file);
    }

    fn getValidConfigFilePath(self: *Config) ![]const u8 {
        const dir_path: []const u8 = try std.fs.getAppDataDir(self.allocator, self.appname);
        defer self.allocator.free(dir_path);

        std.fs.makeDirAbsolute(dir_path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        const config_path: []const u8 = std.fs.path.join(self.allocator, &[_][]const u8{ dir_path, self.config_file }) catch unreachable;
        return config_path;
    }

    fn parse(self: *Config, config_file: std.fs.File) !void {
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

            try self.map.put(groupBuffer[0..(groupLen + name.len)], value);
        }
    }

    fn compareEntries(context: void, left: Entry, right: Entry) bool {
        return std.mem.lessThan(u8, left.key_ptr.*, right.key_ptr.*);
    }

    fn write(self: *Config, config_file: std.fs.File) !void {
        const writer: std.fs.File.Writer = config_file.writer();

        var buffer: []Entry = try self.allocator.alloc(Entry, self.map.count());
        defer self.allocator.free(buffer);

        var ind: usize = 0;
        var it = self.map.iterator();
        while (it.next()) |entry| {
            buffer[ind] = entry;
            ind += 1;
        }

        std.sort.sort(Entry, buffer, {}, compareEntries);

        var current_group: []const u8 = undefined;
        var current_group_len: usize = 0;
        for (buffer) |entry| {
            const group_end: usize = std.mem.indexOf(u8, entry.key_ptr.*, "_") orelse 0;
            if ((group_end != current_group_len) or !std.mem.eql(u8, current_group, entry.key_ptr.*[0..group_end])) {
                current_group_len = group_end;
                current_group = entry.key_ptr.*[0..group_end];
                try writer.print("[{s}]\n", .{current_group});
            }

            try writer.print("{s}={s}\n", .{
                entry.key_ptr.*[(group_end + 1)..],
                entry.value_ptr.*,
            });
        }
    }
};

test "write and load config" {
    // Write
    {
        var write_config: Config = undefined;
        write_config.init(std.testing.allocator, "nyancore", "test.conf");
        defer write_config.deinit();

        try write_config.map.put("test0_key0", "key 0 value");
        try write_config.map.put("test1_key1", "key 1 value");

        try write_config.flush();
    }

    // Read
    {
        var read_config: Config = undefined;
        read_config.init(std.testing.allocator, "nyancore", "test.conf");
        defer read_config.deinit();

        try read_config.load();

        std.testing.expect(std.mem.eql(u8, read_config.map.get("test0_key0") orelse "", "key 0 value"));
        std.testing.expect(std.mem.eql(u8, read_config.map.get("test1_key1") orelse "", "key 1 value"));
    }
}
