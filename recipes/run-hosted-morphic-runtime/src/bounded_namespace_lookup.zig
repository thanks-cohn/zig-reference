const std = @import("std");

pub const max_symlink_traversals: usize = 16;
pub const Kind = enum { regular, directory, symlink };
pub const Object = struct {
    kind: Kind,
    manifest_offset: usize,
    data_offset: usize = 0,
    data_length: usize = 0,
    traversals: usize = 0,
};
pub const Error = error{ InvalidPath, NotFound, MalformedObject, FinalSymlink, TraversalLimit };

pub fn validAbsolutePath(path: []const u8) bool {
    if (std.mem.eql(u8, path, "/")) return true;
    if (path.len < 2 or path[0] != '/' or path[path.len - 1] == '/') return false;
    var components = std.mem.splitScalar(u8, path[1..], '/');
    while (components.next()) |component|
        if (component.len == 0 or std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return false;
    return true;
}

fn stringAfter(source: []const u8, key: []const u8) ?[]const u8 {
    const relative = std.mem.indexOf(u8, source, key) orelse return null;
    const begin = relative + key.len;
    const end = std.mem.indexOfScalarPos(u8, source, begin, '"') orelse return null;
    if (std.mem.indexOfScalar(u8, source[begin..end], '\\') != null) return null;
    return source[begin..end];
}

fn unsignedAfter(source: []const u8, key: []const u8) ?usize {
    const relative = std.mem.indexOf(u8, source, key) orelse return null;
    var cursor = relative + key.len;
    if (cursor == source.len or !std.ascii.isDigit(source[cursor])) return null;
    var value: usize = 0;
    while (cursor < source.len and std.ascii.isDigit(source[cursor])) : (cursor += 1)
        value = std.math.add(usize, std.math.mul(usize, value, 10) catch return null, source[cursor] - '0') catch return null;
    return value;
}

const Found = struct { object: Object, target: ?[]const u8 = null };

fn find(manifest: []const u8, path: []const u8) Error!Found {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, manifest, cursor, "\"path\":\"")) |at| {
        const object_end = std.mem.indexOfScalarPos(u8, manifest, at, '}') orelse return error.MalformedObject;
        const object_begin = std.mem.lastIndexOfScalar(u8, manifest[0..at], '{') orelse return error.MalformedObject;
        const row = manifest[object_begin .. object_end + 1];
        const found_path = stringAfter(row, "\"path\":\"") orelse return error.MalformedObject;
        if (std.mem.eql(u8, found_path, path)) {
            const kind_text = stringAfter(row, "\"kind\":\"") orelse return error.MalformedObject;
            if (std.mem.eql(u8, kind_text, "directory")) return .{ .object = .{ .kind = .directory, .manifest_offset = object_begin } };
            if (std.mem.eql(u8, kind_text, "symlink")) return .{
                .object = .{ .kind = .symlink, .manifest_offset = object_begin },
                .target = stringAfter(row, "\"target\":\"") orelse return error.MalformedObject,
            };
            if (!std.mem.eql(u8, kind_text, "regular")) return error.MalformedObject;
            return .{ .object = .{
                .kind = .regular,
                .manifest_offset = object_begin,
                .data_offset = unsignedAfter(row, "\"data_offset\":") orelse return error.MalformedObject,
                .data_length = unsignedAfter(row, "\"data_length\":") orelse return error.MalformedObject,
            } };
        }
        cursor = object_end + 1;
    }
    return error.NotFound;
}

/// Returns the exact namespace object named by `guest_path` without following
/// its final symlink. This is the canonical identity source for lstat-style
/// metadata; ordinary stat/open callers use `resolve` and therefore share the
/// resolved target object's `manifest_offset`.
pub fn resolveFinalObject(manifest: []const u8, guest_path: []const u8) Error!Object {
    if (!validAbsolutePath(guest_path)) return error.InvalidPath;
    return (try find(manifest, guest_path)).object;
}

pub fn resolve(manifest: []const u8, guest_path: []const u8, follow_final_symlink: bool) Error!Object {
    if (!validAbsolutePath(guest_path)) return error.InvalidPath;
    var path = guest_path;
    var traversals: usize = 0;
    while (true) {
        const found = try find(manifest, path);
        const target = found.target orelse {
            var result = found.object;
            result.traversals = traversals;
            return result;
        };
        if (!follow_final_symlink) return error.FinalSymlink;
        if (traversals == max_symlink_traversals) return error.TraversalLimit;
        if (!validAbsolutePath(target)) return error.InvalidPath;
        traversals += 1;
        path = target;
    }
}

const fixture =
    "{\"path\":\"/\",\"kind\":\"directory\"}," ++
    "{\"path\":\"/real\",\"kind\":\"regular\",\"data_offset\":4,\"data_length\":7}," ++
    "{\"path\":\"/link\",\"kind\":\"symlink\",\"target\":\"/real\"}," ++
    "{\"path\":\"/cycle-a\",\"kind\":\"symlink\",\"target\":\"/cycle-b\"}," ++
    "{\"path\":\"/cycle-b\",\"kind\":\"symlink\",\"target\":\"/cycle-a\"}";

test "ordinary symlink open resolves target identity" {
    const object = try resolve(fixture, "/link", true);
    try std.testing.expectEqual(Kind.regular, object.kind);
    try std.testing.expectEqual(@as(usize, 4), object.data_offset);
    try std.testing.expectEqual(@as(usize, 1), object.traversals);
}

test "followed and no-follow identities select target and link objects" {
    const target = try resolve(fixture, "/real", true);
    const followed = try resolve(fixture, "/link", true);
    const link = try resolveFinalObject(fixture, "/link");
    try std.testing.expectEqual(target.manifest_offset, followed.manifest_offset);
    try std.testing.expect(link.manifest_offset != followed.manifest_offset);
    try std.testing.expectEqual(Kind.symlink, link.kind);
}

test "no-follow rejects final symlink" {
    try std.testing.expectError(error.FinalSymlink, resolve(fixture, "/link", false));
}

test "cyclic traversal reaches the bounded limit" {
    try std.testing.expectError(error.TraversalLimit, resolve(fixture, "/cycle-a", true));
}

test "root directory remains directly openable" {
    const object = try resolve(fixture, "/", true);
    try std.testing.expectEqual(Kind.directory, object.kind);
    try std.testing.expectEqual(@as(usize, 0), object.traversals);
}
