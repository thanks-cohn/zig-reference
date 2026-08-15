const std = @import("std");

pub const Permissions = packed struct { read: bool = false, write: bool = false, execute: bool = false };
pub const PlanError = error{ InvalidArgument, PermissionDenied, FileRange, AddressOverflow };

pub const Plan = struct {
    file_offset: usize,
    byte_length: usize,
    mapped_length: usize,
    permissions: Permissions,

    /// Copies immutable namespace bytes into private, caller-owned pages and
    /// deterministically clears the last-page tail.
    pub fn prepare(self: Plan, source: []const u8, destination: []u8) void {
        std.debug.assert(destination.len == self.mapped_length);
        @memset(destination, 0);
        @memcpy(destination[0..self.byte_length], source[self.file_offset..][0..self.byte_length]);
    }
};

/// Plans only the evidence-backed Linux/RV64 file MAP_PRIVATE slice. The file
/// range and rounded private backing are checked before any mapping mutation.
pub fn plan(file_size: usize, length: usize, protection: usize, flags: usize, offset: usize, page_size: usize) PlanError!Plan {
    if (length == 0 or page_size == 0 or page_size & (page_size - 1) != 0 or offset & (page_size - 1) != 0 or flags != 0x2 or protection & ~@as(usize, 0x7) != 0)
        return error.InvalidArgument;
    const permissions: Permissions = .{ .read = protection & 1 != 0, .write = protection & 2 != 0, .execute = protection & 4 != 0 };
    if (permissions.write and permissions.execute) return error.PermissionDenied;
    if (offset > file_size) return error.FileRange;
    const rounded = std.math.add(usize, length, page_size - 1) catch return error.AddressOverflow;
    const mapped_length = rounded & ~(page_size - 1);
    return .{ .file_offset = offset, .byte_length = @min(length, file_size - offset), .mapped_length = mapped_length, .permissions = permissions };
}

test "private executable mapping copies exact range and clears page tail" {
    const source = "0123456789abcdef";
    const prepared = try plan(source.len, 6, 5, 2, 4, 4);
    var private: [8]u8 = undefined;
    prepared.prepare(source, &private);
    try std.testing.expectEqualStrings("456789", private[0..6]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, private[6..]);
    private[0] = 'X';
    try std.testing.expectEqual(@as(u8, '4'), source[4]);
    try std.testing.expect(prepared.permissions.read and prepared.permissions.execute and !prepared.permissions.write);
}

test "invalid class range alignment and W plus X fail closed" {
    try std.testing.expectError(error.InvalidArgument, plan(16, 4, 1, 1, 0, 4));
    try std.testing.expectError(error.InvalidArgument, plan(16, 4, 1, 2, 1, 4));
    const tail = try plan(16, 8, 1, 2, 12, 4);
    try std.testing.expectEqual(@as(usize, 4), tail.byte_length);
    try std.testing.expectError(error.FileRange, plan(16, 4, 1, 2, 20, 4));
    try std.testing.expectError(error.PermissionDenied, plan(16, 4, 7, 2, 0, 4));
}
