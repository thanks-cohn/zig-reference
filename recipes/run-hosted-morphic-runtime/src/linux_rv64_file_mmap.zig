const std = @import("std");

pub const ResolveError = error{ BadDescriptor, UnsupportedResource };

pub fn resolveRegular(resources: anytype, bindings: anytype, descriptor: usize, regular_backend: u32) ResolveError!@TypeOf(resources.*).Description {
    const reference = bindings.resolve(descriptor) orelse return error.BadDescriptor;
    const description = resources.resolve(reference) orelse return error.BadDescriptor;
    if (@intFromEnum(description.backend) != regular_backend) return error.UnsupportedResource;
    return description;
}

pub const Permissions = packed struct { read: bool = false, write: bool = false, execute: bool = false };
pub const PlanError = error{ InvalidArgument, PermissionDenied, FileRange, AddressOverflow };

pub const Plan = struct {
    file_offset: usize,
    byte_length: usize,
    mapped_length: usize,
    page_size: usize,
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
    return .{ .file_offset = offset, .byte_length = @min(length, file_size - offset), .mapped_length = mapped_length, .page_size = page_size, .permissions = permissions };
}

/// Owns the failure-atomic reserve/prepare/map transaction used by the runtime.
/// The context supplies `occupied`, `prepare`, `mapPage`, and `unmapPage`.
pub fn mapPrivate(plan_value: Plan, start: usize, mappings: anytype, context: anytype, page_occupied: fn (@TypeOf(context), usize) bool) !void {
    try mappings.reserve(start, plan_value.mapped_length, .{
        .read = plan_value.permissions.read,
        .write = plan_value.permissions.write,
        .execute = plan_value.permissions.execute,
    }, false, context, page_occupied);
    context.prepare(plan_value) catch |err| {
        mappings.cancelLast(start, plan_value.mapped_length);
        return err;
    };
    const page_count = plan_value.mapped_length / plan_value.page_size;
    var mapped: usize = 0;
    while (mapped < page_count) : (mapped += 1) {
        context.mapPage(start + mapped * plan_value.page_size, mapped, plan_value.permissions) catch |err| {
            var rollback: usize = 0;
            while (rollback < mapped) : (rollback += 1)
                context.unmapPage(start + rollback * plan_value.page_size) catch unreachable;
            mappings.cancelLast(start, plan_value.mapped_length);
            return err;
        };
    }
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

test "descriptor resolution preserves position and resource ownership" {
    const resource_tables = @import("bounded-resource-table");
    const Resources = resource_tables.ResourceTable(2);
    const Bindings = resource_tables.BindingTable(Resources.ResourceRef, 4);
    var resources = Resources{};
    var bindings = Bindings{};
    const reference = try resources.create(.{ .backend = @enumFromInt(0x101), .capabilities = .{}, .state = (@as(usize, 17) << 32) | 29 });
    try bindings.bindAt(3, reference);

    try std.testing.expectError(error.BadDescriptor, resolveRegular(&resources, &bindings, 2, 0x101));
    const before = resources.resolve(reference).?;
    const resolved = try resolveRegular(&resources, &bindings, 3, 0x101);
    try std.testing.expectEqual(before.state, resolved.state);
    try std.testing.expectEqual(@as(usize, 1), resources.count());
    try std.testing.expectEqual(@as(?usize, 1), resources.referenceCount(reference));
    try std.testing.expectEqual(reference, bindings.resolve(3).?);
}

test "capacity collision and forced mapping failure leave no reservation" {
    const runtime_mappings = @import("bounded_runtime_mappings.zig");
    const Table = runtime_mappings.BoundedRuntimeMappings(1, 4);
    const Context = struct {
        fail_page: ?usize = null,
        installed: usize = 0,
        source: [8]u8 = .{ 1, 2, 3, 4, 5, 6, 7, 8 },
        private: [8]u8 = undefined,

        fn occupied(_: *@This(), address: usize) bool {
            return address == 0x3000;
        }
        fn prepare(self: *@This(), prepared: Plan) !void {
            prepared.prepare(&self.source, &self.private);
        }
        fn mapPage(self: *@This(), _: usize, index: usize, _: Permissions) error{ForcedMapFailure}!void {
            if (self.fail_page == index) return error.ForcedMapFailure;
            self.installed += 1;
        }
        fn unmapPage(self: *@This(), _: usize) !void {
            self.installed -= 1;
        }
    };
    const prepared = try plan(8, 8, 5, 2, 0, 4);

    var collision_table: Table = .{};
    var collision_context: Context = .{};
    try std.testing.expectError(error.Collision, mapPrivate(prepared, 0x3000, &collision_table, &collision_context, Context.occupied));
    try std.testing.expectEqual(@as(usize, 0), collision_table.count);

    var failure_table: Table = .{};
    var failure_context: Context = .{ .fail_page = 1 };
    try std.testing.expectError(error.ForcedMapFailure, mapPrivate(prepared, 0x4000, &failure_table, &failure_context, Context.occupied));
    try std.testing.expectEqual(@as(usize, 0), failure_table.count);
    try std.testing.expectEqual(@as(usize, 0), failure_context.installed);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5, 6, 7, 8 }, &failure_context.source);

    try failure_table.reserve(0x5000, 4, .{}, false, &failure_context, Context.occupied);
    var full_context: Context = .{};
    try std.testing.expectError(error.CapacityExceeded, mapPrivate(prepared, 0x6000, &failure_table, &full_context, Context.occupied));
    try std.testing.expectEqual(@as(usize, 1), failure_table.count);
}
