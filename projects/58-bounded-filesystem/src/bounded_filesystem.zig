const std = @import("std");

pub const ObjectId = enum(u16) { root = 0, _ };
pub const Kind = enum { file, directory };
pub const Error = error{ InvalidPath, NameTooLong, NotFound, NotDirectory, IsDirectory, NoSpace, FileTooLarge, InvalidObject, OffsetOverflow };

pub fn FileSystem(comptime object_capacity: usize, comptime name_capacity: usize, comptime file_capacity: usize) type {
    if (object_capacity == 0)
        @compileError("ZIGREF-FILESYSTEM-INVALID-CAPACITY: object_capacity must include the root object");
    if (object_capacity > @as(usize, std.math.maxInt(u16)) + 1)
        @compileError("ZIGREF-FILESYSTEM-INVALID-CAPACITY: object_capacity exceeds the ObjectId namespace");
    return struct {
        const Self = @This();
        pub const Object = struct {
            kind: Kind = .file,
            parent: ObjectId = .root,
            name: [name_capacity]u8 = .{0} ** name_capacity,
            name_len: usize = 0,
            bytes: [file_capacity]u8 = .{0} ** file_capacity,
            length: usize = 0,
        };
        objects: [object_capacity]Object = initObjects(),
        count: usize = 1,

        fn initObjects() [object_capacity]Object {
            var result = [_]Object{.{}} ** object_capacity;
            result[0].kind = .directory;
            return result;
        }

        pub fn create(self: *Self, parent: ObjectId, name: []const u8, kind: Kind, bytes: []const u8) Error!ObjectId {
            if (self.resolve(parent) == null) return error.InvalidObject;
            if (self.resolve(parent).?.kind != .directory) return error.NotDirectory;
            try validateComponent(name);
            if (bytes.len > file_capacity) return error.FileTooLarge;
            if (self.child(parent, name) != null) return error.InvalidPath;
            if (self.count == object_capacity) return error.NoSpace;
            const index = self.count;
            var next = Object{ .kind = kind, .parent = parent, .name_len = name.len, .length = bytes.len };
            @memcpy(next.name[0..name.len], name);
            @memcpy(next.bytes[0..bytes.len], bytes);
            self.objects[index] = next;
            self.count += 1;
            return @enumFromInt(index);
        }

        pub fn lookup(self: *const Self, start: ObjectId, path: []const u8) Error!ObjectId {
            if (path.len == 0) return error.InvalidPath;
            var current: ObjectId = if (path[0] == '/') .root else start;
            var rest = if (path[0] == '/') path[1..] else path;
            if (rest.len == 0) return .root;
            while (rest.len != 0) {
                const slash = std.mem.indexOfScalar(u8, rest, '/');
                const component = if (slash) |at| rest[0..at] else rest;
                try validateComponent(component);
                const object = self.resolve(current) orelse return error.InvalidObject;
                if (object.kind != .directory) return error.NotDirectory;
                current = self.child(current, component) orelse return error.NotFound;
                rest = if (slash) |at| rest[at + 1 ..] else "";
                if (rest.len == 0 and slash != null) return error.InvalidPath;
            }
            return current;
        }

        pub fn read(self: *const Self, id: ObjectId, offset: usize, destination: []u8) Error!usize {
            const object = self.resolve(id) orelse return error.InvalidObject;
            if (object.kind != .file) return error.IsDirectory;
            if (offset >= object.length) return 0;
            const count = @min(destination.len, object.length - offset);
            @memcpy(destination[0..count], object.bytes[offset .. offset + count]);
            return count;
        }

        pub fn resolve(self: *const Self, id: ObjectId) ?*const Object {
            const index: usize = @intFromEnum(id);
            return if (index < self.count) &self.objects[index] else null;
        }

        fn child(self: *const Self, parent: ObjectId, name: []const u8) ?ObjectId {
            for (self.objects[1..self.count], 1..) |object, index|
                if (object.parent == parent and std.mem.eql(u8, object.name[0..object.name_len], name)) return @enumFromInt(index);
            return null;
        }

        fn validateComponent(name: []const u8) Error!void {
            if (name.len == 0 or std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..") or std.mem.indexOfScalar(u8, name, '/') != null or std.mem.indexOfScalar(u8, name, 0) != null) return error.InvalidPath;
            if (name.len > name_capacity) return error.NameTooLong;
        }
    };
}

test "root-relative traversal and exact bounded reads" {
    var fs = FileSystem(5, 12, 32){};
    const bin = try fs.create(.root, "bin", .directory, "");
    const app = try fs.create(bin, "app", .file, "file-26");
    try std.testing.expectEqual(app, try fs.lookup(.root, "/bin/app"));
    var bytes: [8]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 7), try fs.read(app, 0, &bytes));
    try std.testing.expectEqualStrings("file-26", bytes[0..7]);
    try std.testing.expectEqual(@as(usize, 2), try fs.read(app, 5, &bytes));
}

test "failed lookup and creation preserve state" {
    var fs = FileSystem(2, 4, 4){};
    const before = fs;
    try std.testing.expectError(error.NotFound, fs.lookup(.root, "/no"));
    try std.testing.expectEqualDeep(before, fs);
    try std.testing.expectError(error.NameTooLong, fs.create(.root, "longer", .file, ""));
    try std.testing.expectEqualDeep(before, fs);
}
