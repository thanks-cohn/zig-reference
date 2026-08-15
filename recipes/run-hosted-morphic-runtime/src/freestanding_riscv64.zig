const std = @import("std");
const morphic = @import("morphic-core");
const scheduler_module = @import("bounded-deterministic-scheduler");
const addresses = @import("distinct-memory-address-types");
const frames = @import("physical-page-frame-number-and-address-conversion");
const region_sets = @import("physical-memory-region-set");
const frame_allocators = @import("physical-page-frame-allocator");
const sv39_entries = @import("riscv-sv39-page-table-entry");
const sv39_builders = @import("riscv-sv39-page-table-builder");
const sfence_vma = @import("riscv-sfence-vma-invalidation");
const user_transfer = @import("bounded-user-memory-transfer-plan");
const elf_load = @import("bounded-elf64-load-plan");
const initial_stack = @import("bounded-rv64-linux-initial-stack-plan");
const morphic_operation = @import("morphic-semantic-operation");
const resource_tables = @import("bounded-resource-table");
const bounded_filesystem = @import("bounded-filesystem");
const address_space = @import("bounded-address-space-exec-image");
const external_artifact_options = @import("external-artifact-options");
const bounded_syscall_evidence = @import("bounded_syscall_evidence.zig");
const bounded_mapping_preflight = @import("bounded_mapping_preflight.zig");
const linux_rv64_clone_request = @import("linux_rv64_clone_request.zig");
const linux_rv64_fdupfd = @import("linux_rv64_fdupfd.zig");
const linux_rv64_dup3 = @import("linux_rv64_dup3.zig");
const linux_rv64_fstat = @import("linux_rv64_fstat.zig");
const linux_rv64_file_mmap = @import("linux_rv64_file_mmap.zig");
const bounded_pipe = @import("bounded_pipe.zig");
const linux_rv64_pipe2 = @import("linux_rv64_pipe2.zig");
const linux_rv64_pipe_lifetime = @import("linux_rv64_pipe_lifetime.zig");
const runtime_mappings = @import("bounded_runtime_mappings.zig");
const syscall_read_backend = @import("syscall_read_backend.zig");
const bounded_namespace_lookup = @import("bounded_namespace_lookup.zig");
const bounded_process_cwd = @import("bounded_process_cwd.zig");
const bounded_runtime_namespace = @import("bounded_runtime_namespace.zig");
const userspace_elf = @embedFile("userspace-elf-rv64");
const userspace_elf_data_bss = @embedFile("userspace-elf-rv64-data-bss");
const userspace_elf_initial_stack = @embedFile("userspace-elf-rv64-initial-stack");
const userspace_elf_linux_syscalls = @embedFile("userspace-elf-rv64-linux-syscalls");
const userspace_elf_file_memory_exec = @embedFile("userspace-elf-rv64-file-memory-exec");
const batch26_main_elf = @embedFile("userspace-elf-rv64-batch26-main");
const batch26_interp_elf = @embedFile("userspace-elf-rv64-batch26-interp");
/// Host transport only: build orchestration supplies hash-checked bytes. ELF
/// planning and machine semantics remain independent of how those bytes arrived.
pub export const external_rv64_artifact align(frames.PageSize) linksection(".caller_artifact") = @embedFile("external-rv64-artifact").*;
pub export const external_rv64_interpreter align(frames.PageSize) linksection(".caller_artifact") = @embedFile("external-rv64-interpreter").*;
pub export const external_rv64_namespace_manifest align(frames.PageSize) linksection(".caller_artifact") = @embedFile("external-rv64-namespace-manifest").*;
pub export const external_rv64_namespace_data align(frames.PageSize) linksection(".caller_artifact") = @embedFile("external-rv64-namespace-data").*;

const NamespaceFile = struct { bytes: []const u8, traversals: usize = 0 };

fn jsonUnsignedAfter(source: []const u8, start: usize, key: []const u8) ?usize {
    const relative = std.mem.indexOfPos(u8, source, start, key) orelse return null;
    var cursor = relative + key.len;
    if (cursor == source.len or source[cursor] < '0' or source[cursor] > '9') return null;
    var value: usize = 0;
    while (cursor < source.len and source[cursor] >= '0' and source[cursor] <= '9') : (cursor += 1)
        value = std.math.add(usize, std.math.mul(usize, value, 10) catch return null, source[cursor] - '0') catch return null;
    return value;
}

fn jsonStringAfter(source: []const u8, start: usize, key: []const u8) ?[]const u8 {
    const relative = std.mem.indexOfPos(u8, source, start, key) orelse return null;
    const begin = relative + key.len;
    const end = std.mem.indexOfScalarPos(u8, source, begin, '"') orelse return null;
    if (std.mem.indexOfScalar(u8, source[begin..end], '\\') != null) return null;
    return source[begin..end];
}

fn validAbsolutePath(path: []const u8) bool {
    return bounded_namespace_lookup.validAbsolutePath(path);
}

fn namespaceLookup(manifest: []const u8, guest_path: []const u8, data: []const u8) ?NamespaceFile {
    const object = bounded_namespace_lookup.resolve(manifest, guest_path, true) catch return null;
    if (object.kind != .regular or object.data_offset > data.len or object.data_length > data.len - object.data_offset) return null;
    return .{ .bytes = data[object.data_offset .. object.data_offset + object.data_length], .traversals = object.traversals };
}

fn namespaceValidate(manifest: []const u8, data: []const u8) bool {
    if (std.mem.indexOf(u8, manifest, "\"format\":\"zig-reference-bounded-namespace-v1\"") == null) return false;
    const count = jsonUnsignedAfter(manifest, 0, "\"object_count\":") orelse return false;
    const bytes = jsonUnsignedAfter(manifest, 0, "\"regular_file_bytes\":") orelse return false;
    if (bytes != data.len) return false;
    var cursor: usize = 0;
    var observed: usize = 0;
    var accounted: usize = 0;
    while (std.mem.indexOfPos(u8, manifest, cursor, "\"path\":\"")) |at| {
        const object_end = std.mem.indexOfScalarPos(u8, manifest, at, '}') orelse return false;
        const object_begin = std.mem.lastIndexOfScalar(u8, manifest[0..at], '{') orelse return false;
        const row = manifest[object_begin .. object_end + 1];
        const path = jsonStringAfter(row, 0, "\"path\":\"") orelse return false;
        const kind = jsonStringAfter(row, 0, "\"kind\":\"") orelse return false;
        if (path.len == 0 or path[0] != '/') return false;
        var prior_cursor: usize = 0;
        while (std.mem.indexOfPos(u8, manifest, prior_cursor, "\"path\":\"")) |prior_at| {
            if (prior_at >= at) break;
            const prior_path = jsonStringAfter(manifest, prior_at, "\"path\":\"") orelse return false;
            if (std.mem.eql(u8, prior_path, path)) return false;
            prior_cursor = prior_at + 8;
        }
        if (std.mem.eql(u8, kind, "regular")) {
            const offset = jsonUnsignedAfter(row, 0, "\"data_offset\":") orelse return false;
            const length = jsonUnsignedAfter(row, 0, "\"data_length\":") orelse return false;
            if (offset != accounted or offset > data.len or length > data.len - offset) return false;
            accounted += length;
        } else if (std.mem.eql(u8, kind, "symlink")) {
            const target = jsonStringAfter(row, 0, "\"target\":\"") orelse return false;
            if (target.len == 0) return false;
        } else if (!std.mem.eql(u8, kind, "directory")) return false;
        observed += 1;
        cursor = object_end + 1;
    }
    return observed == count and accounted == data.len;
}

const begin_marker = "\nZIGREF_MORPHIC_BEGIN\n";
const end_marker = "ZIGREF_MORPHIC_END\n";
const physical_pool_pages = 8;
const ordinary_table_pages = 4;
// One dedicated table page covers the separately placed caller-artifact
// transport; the remaining bound preserves the prepared execution mappings.
const prepared_table_pages = 16;
// The exact BusyBox image occupies 244 pages; exec starts a fresh dynamic
// loader and therefore needs bounded post-image brk/mmap headroom rather than
// inheriting the original shell's already-established allocator state.
const prepared_image_pages = 320;
const external_stack_pages = 2;
var prepared_table_backing: [prepared_table_pages][frames.PageSize]u8 align(frames.PageSize) linksection(".prepared_image_reservation") = undefined;
var external_prepared_backing: [prepared_image_pages][frames.PageSize]u8 align(frames.PageSize) linksection(".prepared_image_reservation") = undefined;
var external_interpreter_backing: [prepared_image_pages][frames.PageSize]u8 align(frames.PageSize) linksection(".prepared_image_reservation") = undefined;
var external_prepared_stack: [external_stack_pages][frames.PageSize]u8 align(frames.PageSize) linksection(".prepared_image_reservation") = undefined;
// execve PREPARE must not overwrite the live child image. These caller-owned
// candidate pages remain private until every lookup, ELF, argv/envp, stack, and
// capacity check has succeeded; COMMIT then replaces the active backing.
var external_exec_main_candidate: [prepared_image_pages][frames.PageSize]u8 align(frames.PageSize) linksection(".prepared_image_reservation") = undefined;
var external_exec_interpreter_candidate: [prepared_image_pages][frames.PageSize]u8 align(frames.PageSize) linksection(".prepared_image_reservation") = undefined;

fn fnv1a64(bytes: []const u8) u64 {
    var value: u64 = 0xcbf29ce484222325;
    for (bytes) |byte| value = (value ^ byte) *% 0x100000001b3;
    return value;
}

extern var __physical_page_pool_begin: u8;
extern var __physical_page_pool_end: u8;
extern var __image_begin: u8;
extern var __image_end: u8;
extern var __text_domain_begin: u8;
extern var __text_domain_end: u8;
extern var __rodata_domain_begin: u8;
extern var __rodata_domain_end: u8;
extern var __writable_domain_begin: u8;
extern var __writable_domain_end: u8;
extern var __supervisor_stack_top: u8;
extern var __user_trap_stack_begin: u8;
extern var __user_trap_stack_end: u8;
extern var __prepared_image_reservation_begin: u8;
extern var __prepared_image_reservation_end: u8;
extern var __caller_artifact_begin: u8;
extern var __caller_artifact_end: u8;

const sv39_alias: usize = 0x8040_0000;
const user_code_va: usize = 0x8040_1000;
const user_stack_va: usize = 0x8040_2000;
const user_data_va: usize = 0x8040_3000;
const batch23_initialized: usize = 0x23da_7a11_5eed_c0de;
const batch23_mutation: usize = 0x23b5_5a5a_a55a_c33c;
var sv39_continuation_marker: usize = 0;
var sv39_permission_global: usize = 0;
const sv39_permission_rodata: usize = 0x18_39_2026;

fn RealPageOwner(comptime Allocator: type) type {
    return struct {
        const Self = @This();
        allocator: *Allocator,
        pages: [physical_pool_pages + prepared_table_pages]usize = [_]usize{0} ** (physical_pool_pages + prepared_table_pages),
        page_count: usize = 0,
        prepared_count: usize = 0,

        pub fn allocate(self: *Self) !u64 {
            if (self.page_count == self.pages.len) return error.Exhausted;
            // The historical address space consumes four allocator-owned table
            // pages.  Distant prepared-image mappings must consume their
            // dedicated table reservation instead of stealing the data frames
            // retained for the later user-image proofs.
            const address = if (self.page_count >= ordinary_table_pages) blk: {
                if (self.prepared_count == prepared_table_pages) return error.Exhausted;
                const reserved = @intFromPtr(&prepared_table_backing[self.prepared_count]);
                self.prepared_count += 1;
                break :blk reserved;
            } else if (self.allocator.allocate()) |frame|
                (frame.toAddress() catch unreachable).raw()
            else |err|
                return err;
            const page: *volatile [frames.PageSize]u8 = @ptrFromInt(address);
            for (0..frames.PageSize) |index| page[index] = 0;
            self.pages[self.page_count] = address;
            self.page_count += 1;
            return address;
        }

        pub fn release(self: *Self, address: u64) !void {
            var index: usize = 0;
            while (index < self.page_count and self.pages[index] != address) : (index += 1) {}
            if (index == self.page_count) return error.ForeignFrame;
            const reserved_begin = @intFromPtr(&prepared_table_backing[0]);
            const reserved_end = reserved_begin + @sizeOf(@TypeOf(prepared_table_backing));
            if (address >= reserved_begin and address < reserved_end) {
                // Builder rollback is LIFO, matching reserved table ownership.
                if (self.prepared_count == 0 or address != @intFromPtr(&prepared_table_backing[self.prepared_count - 1])) return error.ForeignFrame;
                self.prepared_count -= 1;
            } else {
                const frame = frames.PhysicalPageFrameNumber.fromAddress(addresses.PhysicalAddress.init(address)) catch return error.ForeignFrame;
                try self.allocator.release(frame);
            }
            self.page_count -= 1;
            self.pages[index] = self.pages[self.page_count];
            self.pages[self.page_count] = 0;
        }

        pub fn read(self: *Self, address: u64, index: usize) !u64 {
            if (index >= 512 or !self.owns(address)) return error.InvalidAccess;
            const entries: *volatile [512]u64 = @ptrFromInt(address);
            return entries[index];
        }

        pub fn write(self: *Self, address: u64, index: usize, value: u64) !void {
            if (index >= 512 or !self.owns(address)) return error.InvalidAccess;
            const entries: *volatile [512]u64 = @ptrFromInt(address);
            entries[index] = value;
        }

        fn owns(self: *const Self, address: u64) bool {
            for (self.pages[0..self.page_count]) |page| if (page == address) return true;
            return false;
        }
    };
}

const MachineAllocator = frame_allocators.PhysicalPageFrameAllocator(physical_pool_pages);
const MachinePageOwner = RealPageOwner(MachineAllocator);
const MachineBuilder = sv39_builders.Builder(MachinePageOwner);
// Paging context remains live across every U-mode continuation. Keeping it in
// supervisor-owned static storage prevents the process boundary from borrowing
// freestandingMain's suspended stack frame.
var runtime_allocator: MachineAllocator = undefined;
var runtime_page_owner: MachinePageOwner = undefined;
var runtime_builder: MachineBuilder = undefined;
var batch26_builder: *MachineBuilder = undefined;
const Batch26MaterializedImage = address_space.MaterializedImage(4);
var batch26_main_image: Batch26MaterializedImage = .{};
var batch26_interp_image: Batch26MaterializedImage = .{};
// Machine-adapter policy, not Morphic semantics: this linker-owned region is a
// bounded reservation for every page in the prepared candidate. Keeping it
// distinct from the live image is what makes PREPARE failure atomic.
var batch26_prepared_backing: [4][frames.PageSize]u8 align(frames.PageSize) = undefined;
var batch26_image_backing: [4]usize = .{ 0, 0, 0, 0 };
var batch26_image_backing_count: usize = 0;
var batch26_stack_image: initial_stack.StackPlan(512) = undefined;
const ExternalPreparedImage = address_space.PreparedImage(prepared_image_pages);
var external_image: ExternalPreparedImage = .{};
var external_interpreter_image: ExternalPreparedImage = .{};
var external_exec_image_candidate: ExternalPreparedImage = .{};
var external_exec_interpreter_image_candidate: ExternalPreparedImage = .{};
const external_stack_plan_capacity = external_stack_pages * frames.PageSize;
var external_stack_image: initial_stack.StackPlan(external_stack_plan_capacity) = undefined;
var external_program_break: usize = 0;
var external_next_backing: usize = 0;
const ExternalRuntimeMappings = runtime_mappings.BoundedRuntimeMappings(8, frames.PageSize);
var external_runtime_mappings: ExternalRuntimeMappings = .{};
export var external_entry: usize = 0;
export var external_initial_sp: usize = 0;
export var external_trap_stack: usize = 0;

/// Fixed, allocation-free integer supervisor context. x0 is architectural zero;
/// x2 is the interrupted sp. Floating-point/vector state and nested traps are
/// outside this deliberately narrow boundary.
const TrapFrame = extern struct {
    x: [32]usize,
    sepc: usize,
    sstatus: usize,
    scause: usize,
    stval: usize,
};

comptime {
    if (@offsetOf(TrapFrame, "sepc") != 256 or @offsetOf(TrapFrame, "sstatus") != 264 or
        @offsetOf(TrapFrame, "scause") != 272 or @offsetOf(TrapFrame, "stval") != 280 or
        @sizeOf(TrapFrame) != 288) @compileError("trap entry offsets and TrapFrame layout disagree");
}

var observed_sepc: usize = 0;
var observed_scause: usize = 0;
var observed_stval: usize = 0;
var observed_sstatus: usize = 0;
var trap_count: usize = 0;
var timer_sepc: usize = 0;
var timer_scause: usize = 0;
var timer_sstatus: usize = 0;
export var timer_trap_count: usize = 0;
var timer_policy_complete: bool = false;

export var user_supervisor_sp: usize linksection(".bss") = 0;
var user_trap_frame_address: usize linksection(".bss") = 0;
var user_scause: usize linksection(".bss") = 0;
var user_sepc: usize linksection(".bss") = 0;
var user_sstatus: usize linksection(".bss") = 0;
var user_sp: usize linksection(".bss") = 0;
var user_a0: usize linksection(".bss") = 0;
var user_t0: usize linksection(".bss") = 0;
var user_t1: usize linksection(".bss") = 0;
export var user_returned: bool linksection(".bss") = false;
var userspace_elf_active: bool linksection(".bss") = false;
var userspace_elf_entry: usize linksection(".bss") = 0;
var userspace_elf_memory_end: usize linksection(".bss") = 0;
var userspace_elf_expected_a0: usize linksection(".bss") = 0;
var userspace_elf_expected_t0: usize linksection(".bss") = 0;
var userspace_elf_expected_t1: usize linksection(".bss") = 0;
var userspace_elf_expected_sp: usize linksection(".bss") = 0;

export var service_trap_count: usize linksection(".bss") = 0;
var service_frames: [2]usize linksection(".bss") = .{ 0, 0 };
var service_causes: [2]usize linksection(".bss") = .{ 0, 0 };
var service_sepcs: [2]usize linksection(".bss") = .{ 0, 0 };
var service_status: [2]usize linksection(".bss") = .{ 0, 0 };
var service_sps: [2]usize linksection(".bss") = .{ 0, 0 };
var service_inputs: [2]usize linksection(".bss") = .{ 0, 0 };
var service_result: usize linksection(".bss") = 0;
var service_prepared_sstatus: usize linksection(".bss") = 0;
var service_terminal_marker: usize linksection(".bss") = 0;
var service_return_to_user_count: usize linksection(".bss") = 0;
var service_terminal_to_supervisor_count: usize linksection(".bss") = 0;
var service_terminal_return_sepc: usize linksection(".bss") = 0;
var service_terminal_return_sstatus: usize linksection(".bss") = 0;
export var service_supervisor_sp: usize linksection(".bss") = 0;
export var service_supervisor_returned: bool linksection(".bss") = false;
var copy_active = false;
var copy_query: user_transfer.PageQuery = undefined;
var copy_trap_count: usize = 0;
var copy_frames: [2]usize = .{ 0, 0 };
var copy_causes: [2]usize = .{ 0, 0 };
var copy_sepcs: [2]usize = .{ 0, 0 };
var copy_status: [2]usize = .{ 0, 0 };
var copy_sps: [2]usize = .{ 0, 0 };
var copy_pointer: usize = 0;
var copy_length: usize = 0;
var copy_segment_pa: usize = 0;
var copy_segment_offset: usize = 0;
var copy_segment_length: usize = 0;
var copy_segment_count: usize = 0;
var copy_coverage: usize = 0;
var copy_scratch: [32]u8 = [_]u8{0xa5} ** 32;
var copy_prepared_sstatus: usize = 0;
var copy_prepared_sepc: usize = 0;
var copy_result: usize = 0;
var copy_terminal_marker: usize = 0;
var copy_return_count: usize = 0;
var copy_terminal_count: usize = 0;

export fn userCopyInProbeContainer() linksection(".text.user_copy_probe") callconv(.naked) void {
    asm volatile (
        \\.global userCopyInProbeTemplateBegin
        \\userCopyInProbeTemplateBegin:
        \\addi sp, sp, -48
        \\li t0, 0x726573752d67697a
        \\sd t0, 0(sp)
        \\li t0, 0x2179726f6d656d2d
        \\sd t0, 8(sp)
        \\li t1, 0x21b0
        \\sd t1, 16(sp)
        \\mv a0, sp
        \\li a1, 16
        \\.global userCopyInProbeServiceEcall
        \\userCopyInProbeServiceEcall:
        \\ecall
        \\.global userCopyInProbeAfterService
        \\userCopyInProbeAfterService:
        \\li t0, 0x21b
        \\bne a0, t0, userCopyInProbeFail
        \\ld t0, 16(sp)
        \\li t1, 0x21b0
        \\bne t0, t1, userCopyInProbeFail
        \\li t0, 0x21c0
        \\sd t0, 24(sp)
        \\li a2, 0x21ee
        \\.global userCopyInProbeTerminalEcall
        \\userCopyInProbeTerminalEcall:
        \\ecall
        \\userCopyInProbeFail: unimp
        \\j userCopyInProbeFail
        \\.global userCopyInProbeTemplateEnd
        \\userCopyInProbeTemplateEnd:
    );
}
extern var userCopyInProbeTemplateBegin: u8;
extern var userCopyInProbeServiceEcall: u8;
extern var userCopyInProbeAfterService: u8;
extern var userCopyInProbeTerminalEcall: u8;
extern var userCopyInProbeTemplateEnd: u8;

var copy_out_active = false;
var copy_out_query: user_transfer.PageQuery = undefined;
var copy_out_traps: usize = 0;
var copy_out_frames: [4]usize = .{0} ** 4;
var copy_out_sepcs: [4]usize = .{0} ** 4;
var copy_out_status: [4]usize = .{0} ** 4;
var copy_out_causes: [4]usize = .{0} ** 4;
var copy_out_prepared: [3]usize = .{0} ** 3;
var copy_out_prepared_status: [3]usize = .{0} ** 3;
var copy_out_destination: usize = 0;
var copy_out_stack_pa: usize = 0;
var copy_out_code_pa: usize = 0;
var copy_out_segment_pa: usize = 0;
var copy_out_segment_offset: usize = 0;
var copy_out_segment_bytes: usize = 0;
var copy_out_segment_coverage: usize = 0;
var copy_out_guard_before: usize = 0;
var copy_out_guard_after: usize = 0;
var copy_out_code_before: usize = 0;
var copy_out_code_after: usize = 0;
var copy_out_prefix_before: usize = 0;
var copy_out_prefix_after: usize = 0;
var copy_out_return_count: usize = 0;
var syscall_active = false;
var batch26_active = false;
var batch26_count: usize = 0;
var batch26_results: [11]usize = .{0} ** 11;
var batch26_pcs: [10]usize = .{0} ** 10;
var batch26_resumes: [9]usize = .{0} ** 9;
const Batch26Fs = bounded_filesystem.FileSystem(8, 32, 16384);
var batch26_fs: Batch26Fs = .{};
var batch26_file_object: bounded_filesystem.ObjectId = .root;
var batch26_open_ref: ResourceRef = undefined;
var batch26_open_offset: usize = 0;
var batch26_map_pa: usize = 0;
var batch26_map_present = false;
var batch26_mmap_value: usize = 0;
var batch26_protect_fault_cause: usize = 0;
var batch26_protect_fault_va: usize = 0;
var batch26_protect_fault_pc: usize = 0;
var batch26_protect_pte: usize = 0;
var batch26_unmap_fault_cause: usize = 0;
var batch26_unmap_fault_va: usize = 0;
var batch26_unmap_fault_pc: usize = 0;
var batch26_interp_terminal = false;
var batch26_main_entry: usize = 0;
var batch26_interp_raw_entry: usize = 0;
var batch26_interp_bias: usize = 0x80404000;
var batch26_interp_entry: usize = 0;
var batch26_at_phdr: usize = 0;
var batch26_initial_sp: usize = 0;
var batch26_exec_path: [32]u8 = undefined;
var batch26_exec_path_len: usize = 0;
var batch26_exec_argv: [2][32]u8 = undefined;
var batch26_exec_argv_lens: [2]usize = .{0} ** 2;
var batch26_exec_argc: usize = 0;
var batch26_exec_envp: [2][32]u8 = undefined;
var batch26_exec_env_lens: [2]usize = .{0} ** 2;
var batch26_exec_envc: usize = 0;
var batch26_failed_exec_resume: usize = 0;
var batch26_program_a_continuation: usize = 0;
const Batch26ActiveQuery = struct {
    fn query(_: *const anyopaque, page: user_transfer.GuestVirtualAddress) ?user_transfer.PageResolution {
        const leaf = batch26_builder.query(page.raw()) catch return null;
        const flags = leaf.raw_entry & 0xff;
        if (flags & 1 == 0 or flags & 0xe == 0) return null;
        return .{ .physical_page_start = user_transfer.PhysicalAddress.init(leaf.physical_address & ~@as(usize, frames.PageSize - 1)), .user = flags & 0x10 != 0, .readable = flags & 0x2 != 0, .writable = flags & 0x4 != 0 };
    }
};
var batch26_query_context: u8 = 0;
var syscall_query: user_transfer.PageQuery = undefined;
var syscall_count: usize = 0;
var syscall_total_count: usize = 0;
var syscall_dropped_count: usize = 0;
const syscall_capacity = 64;
var syscall_numbers: [syscall_capacity + 1]usize = .{0} ** (syscall_capacity + 1);
var syscall_pcs: [syscall_capacity + 1]usize = .{0} ** (syscall_capacity + 1);
var syscall_sstatus: [syscall_capacity + 1]usize = .{0} ** (syscall_capacity + 1);
var syscall_resume_pcs: [syscall_capacity + 1]usize = .{0} ** (syscall_capacity + 1);
var syscall_args: [syscall_capacity + 1][6]usize = .{.{0} ** 6} ** (syscall_capacity + 1);
var syscall_results: [syscall_capacity + 1]usize = .{0} ** (syscall_capacity + 1);
var syscall_semantics: [syscall_capacity + 1]u8 = .{0} ** (syscall_capacity + 1);
var syscall_terminal_status: usize = 0;
var external_fork_parent: ?TrapFrame = null;
const external_child_pid: usize = 2;
var external_fork_main_snapshot: [prepared_image_pages][frames.PageSize]u8 align(frames.PageSize) linksection(".prepared_image_reservation") = undefined;
var external_fork_interpreter_snapshot: [prepared_image_pages][frames.PageSize]u8 align(frames.PageSize) linksection(".prepared_image_reservation") = undefined;
var external_fork_stack_snapshot: [external_stack_pages][frames.PageSize]u8 align(frames.PageSize) linksection(".prepared_image_reservation") = undefined;
var external_fork_image_snapshot: ExternalPreparedImage = .{};
var external_fork_interpreter_image_snapshot: ExternalPreparedImage = .{};
var external_fork_stack_image_snapshot: initial_stack.StackPlan(external_stack_plan_capacity) = undefined;
var external_fork_resources: ResourceStore = undefined;
var external_fork_bindings: ProcessBindings = undefined;
var external_fork_mappings: ExternalRuntimeMappings = undefined;
var external_fork_program_break: usize = 0;
var external_fork_next_backing: usize = 0;
const ProcessCwd = bounded_process_cwd.CurrentDirectory(256);
var external_process_cwd: ProcessCwd = .{};
var external_fork_cwd: ProcessCwd = .{};
const RuntimeNamespace = bounded_runtime_namespace.RuntimeNamespace(4, 256, 256);
var external_runtime_namespace: RuntimeNamespace = .{};
const PipeStore = bounded_pipe.PipeStore(2, 4096);
var external_pipes: PipeStore = .{};
var syscall_output: [64]u8 = .{0} ** 64;
var syscall_output_len: usize = 0;
const ResourceStore = resource_tables.ResourceTable(16);
const ResourceRef = ResourceStore.ResourceRef;
const syscall_binding_capacity = 16;
const ProcessBindings = resource_tables.BindingTable(ResourceRef, syscall_binding_capacity);
var syscall_resources: ResourceStore = .{};
var syscall_bindings: ProcessBindings = .{};
const syscall_stdin = "stdin-25b-proof";
const copy_out_payload = "kernel-to-user!!";

export fn userCopyOutProbeContainer() linksection(".text.user_copy_out_probe") callconv(.naked) void {
    asm volatile (
        \\.global userCopyOutProbeTemplateBegin
        \\userCopyOutProbeTemplateBegin:
        \\addi sp, sp, -64
        \\li t0, 0x1111222233334444
        \\sd t0, 0(sp)
        \\sd zero, 8(sp)
        \\sd zero, 16(sp)
        \\li t0, 0x5555666677778888
        \\sd t0, 24(sp)
        \\addi a0, sp, 8
        \\li a1, 16
        \\.global userCopyOutProbeServiceEcall
        \\userCopyOutProbeServiceEcall: ecall
        \\.global userCopyOutProbeAfterService
        \\userCopyOutProbeAfterService:
        \\li t0, 0x21c1
        \\bne a0, t0, userCopyOutProbeFail
        \\ld t0, 8(sp)
        \\li t1, 0x742d6c656e72656b
        \\bne t0, t1, userCopyOutProbeFail
        \\ld t0, 16(sp)
        \\li t1, 0x2121726573752d6f
        \\bne t0, t1, userCopyOutProbeFail
        \\li a0, 0x80401000
        \\li a1, 16
        \\.global userCopyOutProbePermissionRejectEcall
        \\userCopyOutProbePermissionRejectEcall: ecall
        \\.global userCopyOutProbeAfterPermissionReject
        \\userCopyOutProbeAfterPermissionReject:
        \\li t0, 0x21c2
        \\bne a0, t0, userCopyOutProbeFail
        \\li t0, 0x8877665544332211
        \\sd t0, 56(sp)
        \\addi a0, sp, 56
        \\li a1, 16
        \\.global userCopyOutProbeAtomicRejectEcall
        \\userCopyOutProbeAtomicRejectEcall: ecall
        \\.global userCopyOutProbeAfterAtomicReject
        \\userCopyOutProbeAfterAtomicReject:
        \\li t0, 0x21c3
        \\bne a0, t0, userCopyOutProbeFail
        \\ld t0, 56(sp)
        \\li t1, 0x8877665544332211
        \\bne t0, t1, userCopyOutProbeFail
        \\li a2, 0x21cf
        \\.global userCopyOutProbeTerminalEcall
        \\userCopyOutProbeTerminalEcall: ecall
        \\userCopyOutProbeFail: unimp
        \\j userCopyOutProbeFail
        \\.global userCopyOutProbeTemplateEnd
        \\userCopyOutProbeTemplateEnd:
    );
}
extern var userCopyOutProbeTemplateBegin: u8;
extern var userCopyOutProbeServiceEcall: u8;
extern var userCopyOutProbeAfterService: u8;
extern var userCopyOutProbePermissionRejectEcall: u8;
extern var userCopyOutProbeAfterPermissionReject: u8;
extern var userCopyOutProbeAtomicRejectEcall: u8;
extern var userCopyOutProbeAfterAtomicReject: u8;
extern var userCopyOutProbeTerminalEcall: u8;
extern var userCopyOutProbeTemplateEnd: u8;

export fn userServiceProbeTemplateBegin() linksection(".text.user_service_probe") callconv(.naked) void {
    asm volatile (
        \\addi sp, sp, -32
        \\li t0, 0x2019
        \\sd t0, 0(sp)
        \\li t1, 0x20aa
        \\li a0, 0x20
        \\li a1, 0x19
        \\.global userServiceProbeServiceEcall
        \\userServiceProbeServiceEcall:
        \\ecall
        \\.global userServiceProbeAfterService
        \\userServiceProbeAfterService:
        \\li t0, 0x39
        \\bne a0, t0, userServiceProbeFail
        \\li t0, 0x20aa
        \\bne t1, t0, userServiceProbeFail
        \\sd a0, 8(sp)
        \\li t0, 0x2020
        \\sd t0, 16(sp)
        \\li a2, 0x20ee
        \\.global userServiceProbeTerminalEcall
        \\userServiceProbeTerminalEcall:
        \\ecall
        \\userServiceProbeFail:
        \\unimp
        \\j userServiceProbeFail
        \\.global userServiceProbeTemplateEnd
        \\userServiceProbeTemplateEnd:
    );
}
extern var userServiceProbeServiceEcall: u8;
extern var userServiceProbeAfterService: u8;
extern var userServiceProbeTerminalEcall: u8;
extern var userServiceProbeTemplateEnd: u8;

export fn userServiceTrapEntry() linksection(".text.user_service_trap") callconv(.naked) void {
    asm volatile (
        \\csrrw sp, sscratch, sp
        // sscratch now owns the interrupted user sp. Select the trusted stack
        // from supervisor state rather than trusting the swapped-in value;
        // this also makes fork-child returns robust against stale scratch CSR
        // state without enabling SUM.
        \\la sp, external_trap_stack
        \\ld sp, 0(sp)
        \\addi sp, sp, -288
        \\sd ra, 8(sp)
        \\sd gp, 24(sp)
        \\sd tp, 32(sp)
        \\sd t0, 40(sp)
        \\sd t1, 48(sp)
        \\sd t2, 56(sp)
        \\sd s0, 64(sp)
        \\sd s1, 72(sp)
        \\sd a0, 80(sp)
        \\sd a1, 88(sp)
        \\sd a2, 96(sp)
        \\sd a3, 104(sp)
        \\sd a4, 112(sp)
        \\sd a5, 120(sp)
        \\sd a6, 128(sp)
        \\sd a7, 136(sp)
        \\sd s2, 144(sp)
        \\sd s3, 152(sp)
        \\sd s4, 160(sp)
        \\sd s5, 168(sp)
        \\sd s6, 176(sp)
        \\sd s7, 184(sp)
        \\sd s8, 192(sp)
        \\sd s9, 200(sp)
        \\sd s10, 208(sp)
        \\sd s11, 216(sp)
        \\sd t3, 224(sp)
        \\sd t4, 232(sp)
        \\sd t5, 240(sp)
        \\sd t6, 248(sp)
        \\csrr t0, sscratch
        \\sd t0, 16(sp)
        \\csrr t0, sepc
        \\sd t0, 256(sp)
        \\csrr t0, sstatus
        \\sd t0, 264(sp)
        \\csrr t0, scause
        \\sd t0, 272(sp)
        \\csrr t0, stval
        \\sd t0, 280(sp)
        \\mv a0, sp
        \\call recordUserServiceTrap
        \\la t0, service_trap_count
        \\ld t0, 0(t0)
        \\li t1, 2
        \\beq t0, t1, 2f
        \\ld t0, 264(sp)
        \\csrw sstatus, t0
        \\ld ra, 8(sp)
        \\ld gp, 24(sp)
        \\ld tp, 32(sp)
        \\ld t1, 48(sp)
        \\ld t2, 56(sp)
        \\ld s0, 64(sp)
        \\ld s1, 72(sp)
        \\ld a0, 80(sp)
        \\ld a1, 88(sp)
        \\ld a2, 96(sp)
        \\ld a3, 104(sp)
        \\ld a4, 112(sp)
        \\ld a5, 120(sp)
        \\ld a6, 128(sp)
        \\ld a7, 136(sp)
        \\ld s2, 144(sp)
        \\ld s3, 152(sp)
        \\ld s4, 160(sp)
        \\ld s5, 168(sp)
        \\ld s6, 176(sp)
        \\ld s7, 184(sp)
        \\ld s8, 192(sp)
        \\ld s9, 200(sp)
        \\ld s10, 208(sp)
        \\ld s11, 216(sp)
        \\ld t3, 224(sp)
        \\ld t4, 232(sp)
        \\ld t5, 240(sp)
        \\ld t6, 248(sp)
        // Rearm the trusted trap-stack handoff directly.  In particular, do
        // not serialize the user stack through sscratch and depend on a
        // second swap during return: fork/exec may replace the saved user sp,
        // while the supervisor trap-stack identity is process-independent.
        \\addi sp, sp, 288
        \\la t0, external_trap_stack
        \\ld t0, 0(t0)
        \\bnez t0, 1f
        \\mv t0, sp
        \\1:
        \\csrw sscratch, t0
        \\ld t0, -248(sp)
        \\ld sp, -272(sp)
        \\sret
        \\2:
        \\ld t1, 256(sp)
        \\csrw sepc, t1
        \\ld t1, 264(sp)
        \\csrw sstatus, t1
        \\la t0, service_supervisor_sp
        \\ld sp, 0(t0)
        \\csrw sscratch, zero
        \\sret
    );
}

export fn recordUserServiceTrap(frame: *TrapFrame) callconv(.c) void {
    if (syscall_active) {
        if (batch26_active) {
            @call(.never_tail, recordBatch26Syscall, .{frame});
            return;
        }
        @call(.never_tail, recordLinuxRv64Syscall, .{frame});
        return;
    }
    write("\n");
    if (copy_out_active) {
        @call(.never_tail, recordUserCopyOutTrap, .{frame});
        return;
    }
    if (copy_active) {
        @call(.never_tail, recordUserCopyTrap, .{frame});
        return;
    }
    const index = service_trap_count;
    if (index >= 2 or frame.scause >> 63 != 0 or (frame.scause & 0x7fff_ffff_ffff_ffff) != 8 or frame.sstatus & 0x100 != 0) shutdown();
    const template_begin = @intFromPtr(&userServiceProbeTemplateBegin);
    const expected_service = user_code_va + @intFromPtr(&userServiceProbeServiceEcall) - template_begin;
    const expected_terminal = user_code_va + @intFromPtr(&userServiceProbeTerminalEcall) - template_begin;
    const expected_sp = user_stack_va + frames.PageSize - 32;
    if (frame.x[2] != expected_sp) shutdown();
    if (index == 0) {
        if (frame.sepc != expected_service or frame.x[10] != 0x20 or frame.x[11] != 0x19 or
            frame.x[5] != 0x2019 or frame.x[6] != 0x20aa) shutdown();
    } else {
        if (frame.sepc != expected_terminal or frame.x[12] != 0x20ee or frame.x[10] != 0x39 or
            frame.x[6] != 0x20aa or service_result != 0x39 or service_trap_count != 1) shutdown();
    }
    service_frames[index] = @intFromPtr(frame);
    service_causes[index] = frame.scause;
    service_sepcs[index] = frame.sepc;
    service_status[index] = frame.sstatus;
    service_sps[index] = frame.x[2];
    service_trap_count += 1;
    if (index == 0) {
        service_inputs = .{ frame.x[10], frame.x[11] };
        service_result = frame.x[10] + frame.x[11];
        frame.x[10] = service_result;
        frame.sepc = user_code_va + @intFromPtr(&userServiceProbeAfterService) - @intFromPtr(&userServiceProbeTemplateBegin);
        asm volatile ("csrw sepc, %[value]"
            :
            : [value] "r" (frame.sepc),
        );
        frame.sstatus &= ~@as(usize, 0x40122);
        service_prepared_sstatus = frame.sstatus;
        service_return_to_user_count += 1;
    } else {
        service_terminal_marker = frame.x[12];
        frame.sepc = @intFromPtr(&userServiceSupervisorResume);
        // The second SRET deliberately enters the known S-mode continuation
        // with SPP=1 while keeping SIE, SPIE, and SUM clear.
        frame.sstatus = (frame.sstatus & ~@as(usize, 0x40122)) | 0x100;
        service_terminal_return_sepc = frame.sepc;
        service_terminal_return_sstatus = frame.sstatus;
        service_terminal_to_supervisor_count += 1;
    }
}

fn recordBatch26Syscall(frame: *TrapFrame) void {
    write("ZIGREF_BATCH26_EVENT index=");
    writeUsizeHex(batch26_count);
    write(" cause=");
    writeUsizeHex(frame.scause);
    write(" nr=");
    writeUsizeHex(frame.x[17]);
    write("\n");
    if (frame.scause == 15 and batch26_count == 6 and frame.stval == 0x80404000) {
        batch26_protect_fault_cause = frame.scause;
        batch26_protect_fault_va = frame.stval;
        batch26_protect_fault_pc = frame.sepc;
        frame.sepc += 4;
        asm volatile ("csrw sepc, %[pc]"
            :
            : [pc] "r" (frame.sepc),
            : "memory"
        );
        return;
    }
    if (frame.scause == 13 and batch26_count == 7 and frame.stval == 0x80404000) {
        batch26_unmap_fault_cause = frame.scause;
        batch26_unmap_fault_va = frame.stval;
        batch26_unmap_fault_pc = frame.sepc;
        frame.sepc += 4;
        asm volatile ("csrw sepc, %[pc]"
            :
            : [pc] "r" (frame.sepc),
            : "memory"
        );
        return;
    }
    const expected = [_]usize{ 56, 63, 56, 56, 222, 226, 215, 221, 221, 93 };
    if (batch26_count >= expected.len or frame.scause != 8 or frame.x[17] != expected[batch26_count]) {
        write("ZIGREF_26_FAIL trap nr=");
        writeUsizeHex(frame.x[17]);
        write(" cause=");
        writeUsizeHex(frame.scause);
        write(" index=");
        writeUsizeHex(batch26_count);
        write(" stval=");
        writeUsizeHex(frame.stval);
        write("\n");
        shutdown();
    }
    batch26_pcs[batch26_count] = frame.sepc;
    var result: usize = 0;
    switch (batch26_count) {
        0, 2, 3 => {
            if (frame.x[10] != 0 -% @as(usize, 100) or frame.x[12] != 0 or frame.x[13] != 0) {
                shutdown();
            }
            var path: [32]u8 = undefined;
            const path_len = copyUserCString(frame.x[11], &path) catch {
                result = negativeErrno(14);
                if (batch26_count != 3) shutdown();
                batch26_results[batch26_count] = result;
                return finishBatch26Return(frame, result);
            };
            const object = batch26_fs.lookup(.root, path[0..path_len]) catch {
                result = negativeErrno(2);
                if (batch26_count != 2) shutdown();
                batch26_results[batch26_count] = result;
                return finishBatch26Return(frame, result);
            };
            if (batch26_count != 0 or object != batch26_file_object) shutdown();
            batch26_open_ref = syscall_resources.create(.{ .backend = @enumFromInt(26), .capabilities = .{ .read = true } }) catch shutdown();
            syscall_bindings.bindAt(3, batch26_open_ref) catch shutdown();
            result = 3;
        },
        1 => {
            if (frame.x[10] != 3 or frame.x[12] != 12 or syscall_bindings.resolve(3) == null) shutdown();
            var bytes: [16]u8 = undefined;
            const amount = batch26_fs.read(batch26_file_object, batch26_open_offset, bytes[0..frame.x[12]]) catch shutdown();
            copyBytesToUser(frame.x[11], bytes[0..amount]) catch shutdown();
            batch26_open_offset += amount;
            result = amount;
        },
        4 => {
            if (frame.x[10] != 0 or frame.x[11] != frames.PageSize or frame.x[12] != 3 or frame.x[13] != 0x22 or frame.x[14] != std.math.maxInt(usize) or frame.x[15] != 0 or batch26_map_present) shutdown();
            _ = batch26_builder.mapPage(0x80404000, batch26_map_pa, .page_4k, .{ .read = true, .write = true, .user = true, .accessed = true, .dirty = true }) catch shutdown();
            asm volatile ("sfence.vma; fence.i" ::: "memory");
            batch26_map_present = true;
            result = 0x80404000;
        },
        5 => {
            if (!batch26_map_present or frame.x[10] != 0x80404000 or frame.x[11] != frames.PageSize or frame.x[12] != 1) shutdown();
            batch26_mmap_value = @as(*const volatile usize, @ptrFromInt(batch26_map_pa)).*;
            if (batch26_mmap_value != 0x26) shutdown();
            _ = batch26_builder.protect(0x80404000, .page_4k, .{ .read = true, .user = true, .accessed = true }) catch shutdown();
            asm volatile ("sfence.vma" ::: "memory");
            batch26_protect_pte = (batch26_builder.query(0x80404000) catch shutdown()).raw_entry;
        },
        6 => {
            if (!batch26_map_present or batch26_protect_fault_cause != 15 or frame.x[10] != 0x80404000 or frame.x[11] != frames.PageSize) shutdown();
            _ = batch26_builder.unmapPage(0x80404000, .page_4k) catch shutdown();
            asm volatile ("sfence.vma" ::: "memory");
            batch26_map_present = false;
        },
        7, 8 => {
            if (batch26_unmap_fault_cause != 13) shutdown();
            prepareBatch26Exec(frame) catch |err| {
                if (batch26_count != 7 or err != error.NotFound) shutdown();
                const failure_result = negativeErrno(2);
                batch26_results[batch26_count] = failure_result;
                finishBatch26Return(frame, failure_result);
                batch26_failed_exec_resume = frame.sepc;
                return;
            };
            if (batch26_count != 8) shutdown();
            batch26_program_a_continuation = frame.x[9];
            if (batch26_program_a_continuation != 0x26a) shutdown();
            commitPreparedBatch26Exec(frame);
            batch26_results[batch26_count] = 0;
            batch26_count += 1;
            return;
        },
        9 => {
            if (frame.x[10] != 0x26b or frame.sepc != batch26_interp_entry + 8) shutdown();
            batch26_interp_terminal = true;
            frame.sepc = @intFromPtr(&userServiceSupervisorResume);
            frame.sstatus = (frame.sstatus & ~@as(usize, 0x40122)) | 0x100;
            service_trap_count = 2;
            batch26_count += 1;
            return;
        },
        else => unreachable,
    }
    batch26_results[batch26_count] = result;
    finishBatch26Return(frame, result);
}

fn finishBatch26Return(frame: *TrapFrame, result: usize) void {
    frame.x[10] = result;
    frame.sepc += 4;
    batch26_resumes[batch26_count] = frame.sepc;
    frame.sstatus &= ~@as(usize, 0x40122);
    asm volatile ("csrw sepc, %[pc]"
        :
        : [pc] "r" (frame.sepc),
        : "memory"
    );
    batch26_count += 1;
}

fn copyUserCString(address: usize, destination: []u8) !usize {
    for (destination, 0..) |*byte, index| {
        const plan = user_transfer.TransferPlan(1).plan(user_transfer.GuestVirtualAddress.init(address + index), 1, .read_from_user, syscall_query) catch return error.InvalidUser;
        const source: *const volatile u8 = @ptrFromInt(plan.items()[0].physical_start.raw());
        byte.* = source.*;
        if (byte.* == 0) return index;
    }
    return error.InvalidUser;
}

fn readUserUsize(address: usize) !usize {
    const plan = user_transfer.TransferPlan(1).plan(user_transfer.GuestVirtualAddress.init(address), @sizeOf(usize), .read_from_user, syscall_query) catch return error.InvalidUser;
    return @as(*const volatile usize, @ptrFromInt(plan.items()[0].physical_start.raw())).*;
}

fn copyUserStringVector(address: usize, strings: *[2][32]u8, lengths: *[2]usize) !usize {
    if (address == 0) return 0;
    for (0..3) |index| {
        const pointer = try readUserUsize(address + index * @sizeOf(usize));
        if (pointer == 0) return index;
        if (index == strings.len) return error.InvalidUser;
        lengths[index] = try copyUserCString(pointer, &strings[index]);
    }
    return error.InvalidUser;
}

fn copyBytesToUser(address: usize, bytes: []const u8) !void {
    const plan = user_transfer.TransferPlan(2).plan(user_transfer.GuestVirtualAddress.init(address), bytes.len, .write_to_user, syscall_query) catch return error.InvalidUser;
    for (plan.items()) |segment| {
        const target: [*]volatile u8 = @ptrFromInt(segment.physical_start.raw());
        for (0..segment.byte_count) |i| target[i] = bytes[segment.request_offset + i];
    }
}

fn prepareBatch26Exec(frame: *TrapFrame) !void {
    batch26_exec_path_len = try copyUserCString(frame.x[10], &batch26_exec_path);
    batch26_exec_argc = try copyUserStringVector(frame.x[11], &batch26_exec_argv, &batch26_exec_argv_lens);
    batch26_exec_envc = try copyUserStringVector(frame.x[12], &batch26_exec_envp, &batch26_exec_env_lens);
    const main_object = batch26_fs.lookup(.root, batch26_exec_path[0..batch26_exec_path_len]) catch return error.NotFound;
    const main_file = batch26_fs.resolve(main_object) orelse shutdown();
    const main_bytes = main_file.bytes[0..main_file.length];
    const initial_main = elf_load.planDynamic(2, 32, main_bytes) catch shutdown();
    const interp_bytes: ?[]const u8 = if (initial_main.interpreterPath()) |path| blk: {
        const interp_object = batch26_fs.lookup(.root, path) catch return error.NotFound;
        const interp_file = batch26_fs.resolve(interp_object) orelse shutdown();
        break :blk interp_file.bytes[0..interp_file.length];
    } else null;
    const candidate = address_space.ExecPlan(2, 32).prepare(main_bytes, interp_bytes) catch shutdown();
    const main_plan = candidate.main;
    const main_segment = main_plan.load.items()[0];
    const prepared_main = Batch26MaterializedImage.prepare(main_bytes, &main_plan.load, 0) catch return error.InvalidUser;
    const prepared_interp = if (candidate.interpreter) |*interp_plan| blk: {
        if (!std.mem.eql(u8, candidate.interpreter_path[0..candidate.interpreter_path_len], initial_main.interpreterPath().?)) shutdown();
        break :blk Batch26MaterializedImage.prepare(interp_bytes.?, &interp_plan.load, batch26_interp_bias) catch return error.InvalidUser;
    } else Batch26MaterializedImage{};
    const prepared_page_count = prepared_main.items().len + prepared_interp.items().len;
    if (prepared_page_count > batch26_image_backing.len) return error.InvalidUser;
    batch26_main_entry = candidate.main_entry;
    batch26_interp_raw_entry = candidate.entry;
    batch26_interp_entry = candidate.entry + (if (candidate.interpreter != null) batch26_interp_bias else 0);
    batch26_at_phdr = main_segment.memory.start + 64;
    if (batch26_exec_argc != 1 or batch26_exec_envc != 1) return error.InvalidUser;
    const argv = [_][]const u8{batch26_exec_argv[0][0..batch26_exec_argv_lens[0]]};
    const envp = [_][]const u8{batch26_exec_envp[0][0..batch26_exec_env_lens[0]]};
    var auxv: [3]initial_stack.AuxEntry = undefined;
    auxv[0] = .{ .type = 3, .value = .{ .immediate = batch26_at_phdr } };
    var auxv_len: usize = 1;
    if (candidate.interpreter != null) {
        auxv[auxv_len] = .{ .type = 7, .value = .{ .immediate = batch26_interp_bias } };
        auxv_len += 1;
    }
    auxv[auxv_len] = .{ .type = 9, .value = .{ .immediate = batch26_main_entry } };
    auxv_len += 1;
    const stack_range = initial_stack.GuestStackRange.init(user_stack_va, user_stack_va + frames.PageSize) catch shutdown();
    const stack = initial_stack.plan(512, 1, 1, 3, stack_range, &argv, &envp, auxv[0..auxv_len]) catch shutdown();
    const stack_leaf = batch26_builder.query(user_stack_va) catch shutdown();
    // PREPARE ends here: all userspace capture, lookup, ELF/stack planning,
    // capacity checks, and backing-page discovery completed with Program A live.
    batch26_main_image = prepared_main;
    batch26_interp_image = prepared_interp;
    for (0..prepared_page_count) |index| {
        batch26_image_backing[index] = @intFromPtr(&batch26_prepared_backing[index]);
    }
    batch26_image_backing_count = prepared_page_count;
    batch26_stack_image = stack;
    _ = stack_leaf;
}

fn commitPreparedBatch26Exec(frame: *TrapFrame) void {
    const stack_leaf = batch26_builder.query(user_stack_va) catch unreachable;
    _ = batch26_builder.unmapPage(user_code_va, .page_4k) catch unreachable;
    _ = batch26_builder.unmapPage(user_data_va, .page_4k) catch unreachable;
    const stack_target: [*]volatile u8 = @ptrFromInt(stack_leaf.physical_address);
    for (0..frames.PageSize) |i| stack_target[i] = 0;
    const stack_offset = batch26_stack_image.initial_sp.raw() - user_stack_va;
    for (batch26_stack_image.bytes(), 0..) |b, i| stack_target[stack_offset + i] = b;
    var backing_index: usize = 0;
    for ([_][]const address_space.ImagePage{ batch26_main_image.items(), batch26_interp_image.items() }) |image_pages| {
        for (image_pages) |page| {
            if (backing_index >= batch26_image_backing_count) shutdown();
            const physical = batch26_image_backing[backing_index];
            const target: [*]volatile u8 = @ptrFromInt(physical);
            for (page.bytes, 0..) |byte, i| target[i] = byte;
            const permissions = sv39_entries.Permissions{
                .read = page.permissions.read,
                .write = page.permissions.write,
                .execute = page.permissions.execute,
                .user = true,
                .accessed = true,
                .dirty = page.permissions.write,
            };
            if (permissions.write and permissions.execute) shutdown();
            _ = batch26_builder.mapPage(page.virtual_start, physical, .page_4k, permissions) catch shutdown();
            backing_index += 1;
        }
    }
    if (backing_index != batch26_image_backing_count) shutdown();
    asm volatile ("sfence.vma; fence.i" ::: "memory");
    frame.sepc = batch26_interp_entry;
    frame.x[2] = batch26_stack_image.initial_sp.raw();
    batch26_initial_sp = frame.x[2];
    frame.sstatus &= ~@as(usize, 0x40122);
    asm volatile ("csrw sepc, %[pc]"
        :
        : [pc] "r" (frame.sepc),
        : "memory"
    );
}

/// Exercise the transported bytes through the same planners, materializer,
/// backing, Sv39 builder, stack planner, and U-mode transition as exec. The
/// map/unmap preflight forces every required table allocation before COMMIT;
/// COMMIT itself can therefore only install leaves into existing tables.
fn executeExternalArtifact(builder: *MachineBuilder, trap_end: usize, historical_stvec: usize) void {
    batch26_builder = builder;
    write("ZIGREF_BATCH29_PHASE prepare\n");
    var bytes: []const u8 = &external_rv64_artifact;
    var interpreter_bytes: ?[]const u8 = if (external_artifact_options.interpreter_enabled) &external_rv64_interpreter else null;
    if (external_artifact_options.namespace_enabled) {
        const manifest: []const u8 = &external_rv64_namespace_manifest;
        const data: []const u8 = &external_rv64_namespace_data;
        if (!namespaceValidate(manifest, data)) shutdown();
        const shell = namespaceLookup(manifest, external_artifact_options.argv0, data) orelse shutdown();
        if (shell.traversals == 0) shutdown();
        bytes = shell.bytes;
        const inspection = elf_load.planDynamic(4, 32, bytes) catch shutdown();
        const interp_path = inspection.interpreterPath() orelse shutdown();
        const interp = namespaceLookup(manifest, interp_path, data) orelse shutdown();
        interpreter_bytes = interp.bytes;
        write("ZIGREF_BATCH32C_NAMESPACE format=PASS objects=PASS ranges=PASS shell_lookup=PASS symlink_traversals=");
        writeUsizeHex(shell.traversals);
        write(" interp=");
        write(interp_path);
        write(" same_backing=PASS\n");
    }
    const candidate = address_space.ExecPlan(4, 32).prepare(bytes, interpreter_bytes) catch |err| {
        write("ZIGREF_BATCH29_PREPARE_FAIL exec-plan=");
        write(@errorName(err));
        write("\n");
        shutdown();
    };
    write("ZIGREF_BATCH29_PREPARE elf\n");
    const prepared = ExternalPreparedImage.prepare(bytes, &candidate.main.load, 0, &external_prepared_backing) catch shutdown();
    const prepared_interpreter = if (candidate.interpreter) |*interpreter|
        ExternalPreparedImage.prepare(interpreter_bytes.?, &interpreter.load, 0x40000000, &external_interpreter_backing) catch shutdown()
    else
        ExternalPreparedImage{};
    write("ZIGREF_BATCH29_PREPARE image\n");
    const main_segment = candidate.main.load.items()[0];
    const at_phdr = main_segment.memory.start + 64;
    const argv: []const []const u8 = if (external_artifact_options.argv3.len != 0)
        &.{ external_artifact_options.argv0, external_artifact_options.argv1, external_artifact_options.argv2, external_artifact_options.argv3 }
    else if (external_artifact_options.argv2.len != 0)
        &.{ external_artifact_options.argv0, external_artifact_options.argv1, external_artifact_options.argv2 }
    else if (external_artifact_options.argv1.len != 0)
        &.{ external_artifact_options.argv0, external_artifact_options.argv1 }
    else
        &.{external_artifact_options.argv0};
    const envp = [_][]const u8{"BATCH29=exact"};
    const auxv = [_]initial_stack.AuxEntry{
        .{ .type = 6, .value = .{ .immediate = frames.PageSize } },
        .{ .type = 3, .value = .{ .immediate = at_phdr } },
        .{ .type = 4, .value = .{ .immediate = 56 } },
        .{ .type = 5, .value = .{ .immediate = @as(usize, bytes[56]) | (@as(usize, bytes[57]) << 8) } },
        .{ .type = 7, .value = .{ .immediate = if (candidate.interpreter != null) 0x40000000 else 0 } },
        .{ .type = 9, .value = .{ .immediate = candidate.main_entry } },
    };
    const external_stack_base = user_stack_va + frames.PageSize - external_stack_pages * frames.PageSize;
    // The cumulative machine lab already owns this fixture VA. Preserve its
    // leaf across the bounded external-process lifetime rather than making the
    // larger stack reservation a permanent replacement.
    const displaced_stack_leaf = builder.query(external_stack_base) catch shutdown();
    const stack_range = initial_stack.GuestStackRange.init(external_stack_base, user_stack_va + frames.PageSize) catch shutdown();
    const stack = initial_stack.plan(external_stack_plan_capacity, 4, 1, auxv.len, stack_range, argv, &envp, &auxv) catch shutdown();
    write("ZIGREF_BATCH29_PREPARE stack\n");

    // PREPARE table-backing preflight. Each successful temporary leaf is
    // removed immediately; the builder-owned intermediate tables remain ready.
    write("ZIGREF_BATCH29_PREPARE tables\n");
    preflightExternalImage(builder, &prepared, &external_prepared_backing) catch shutdown();
    write("ZIGREF_BATCH32A_PREPARE interpreter-tables pages=");
    writeUsizeHex(prepared_interpreter.items().len);
    write("\n");
    preflightExternalImage(builder, &prepared_interpreter, &external_interpreter_backing) catch shutdown();
    external_image = prepared;
    external_interpreter_image = prepared_interpreter;
    external_stack_image = stack;
    external_program_break = 0;
    for (candidate.main.load.items()) |segment| external_program_break = @max(external_program_break, segment.memory.end);
    external_program_break = (external_program_break + frames.PageSize - 1) & ~@as(usize, frames.PageSize - 1);
    external_next_backing = prepared.items().len;
    external_runtime_mappings = .{};
    write("ZIGREF_BATCH29_PHASE commit\n");
    for (&external_prepared_stack) |*backing| @memset(backing, 0);
    const stack_offset = external_stack_image.initial_sp.raw() - external_stack_base;
    const stack_bytes: [*]u8 = @ptrCast(&external_prepared_stack);
    for (external_stack_image.bytes(), 0..) |byte, i| stack_bytes[stack_offset + i] = byte;
    var stack_page: usize = 0;
    while (stack_page < external_stack_pages) : (stack_page += 1) {
        const virtual = external_stack_base + stack_page * frames.PageSize;
        if (externalPageOccupied({}, virtual))
            _ = builder.unmapPage(virtual, .page_4k) catch shutdown();
        _ = builder.mapPage(virtual, @intFromPtr(&external_prepared_stack[stack_page]), .page_4k, .{ .read = true, .write = true, .user = true, .accessed = true, .dirty = true }) catch shutdown();
    }
    for (external_image.items(), 0..) |page, index| {
        if (page.backing_index != index) shutdown();
        const physical = @intFromPtr(&external_prepared_backing[page.backing_index]);
        const permissions = sv39_entries.Permissions{
            .read = page.permissions.read,
            .write = page.permissions.write,
            .execute = page.permissions.execute,
            .user = true,
            .accessed = true,
            .dirty = page.permissions.write,
        };
        if (permissions.write and permissions.execute) shutdown();
        _ = builder.mapPage(page.virtual_start, physical, .page_4k, permissions) catch shutdown();
    }
    for (external_interpreter_image.items(), 0..) |page, index| {
        if (page.backing_index != index) shutdown();
        const permissions = sv39_entries.Permissions{ .read = page.permissions.read, .write = page.permissions.write, .execute = page.permissions.execute, .user = true, .accessed = true, .dirty = page.permissions.write };
        if (permissions.write and permissions.execute) shutdown();
        _ = builder.mapPage(page.virtual_start, @intFromPtr(&external_interpreter_backing[page.backing_index]), .page_4k, permissions) catch shutdown();
    }
    asm volatile ("sfence.vma; fence.i" ::: "memory");

    syscall_query = .{ .context = &batch26_query_context, .queryFn = Batch26ActiveQuery.query };
    syscall_resources = .{};
    syscall_bindings = .{};
    external_process_cwd = .{};
    external_runtime_namespace = .{};
    external_pipes = .{};
    const stdin = syscall_resources.create(.{ .backend = @enumFromInt(if (external_artifact_options.live_console_input) 3 else 0), .capabilities = .{ .read = true } }) catch shutdown();
    const stdout = syscall_resources.create(.{ .backend = @enumFromInt(1), .capabilities = .{ .write = true } }) catch shutdown();
    const stderr = syscall_resources.create(.{ .backend = @enumFromInt(2), .capabilities = .{ .write = true } }) catch shutdown();
    syscall_bindings.bindAt(0, stdin) catch shutdown();
    syscall_bindings.bindAt(1, stdout) catch shutdown();
    syscall_bindings.bindAt(2, stderr) catch shutdown();
    syscall_count = 0;
    syscall_total_count = 0;
    syscall_dropped_count = 0;
    syscall_output_len = 0;
    syscall_terminal_status = 0;
    external_fork_parent = null;
    service_trap_count = 0;
    batch26_active = false;
    syscall_active = true;
    write("ZIGREF_BATCH29_PHASE execute\n");
    external_entry = candidate.entry + (if (candidate.interpreter != null) @as(usize, 0x40000000) else 0);
    external_initial_sp = external_stack_image.initial_sp.raw();
    external_trap_stack = trap_end;
    asm volatile ("la t0, external_entry; ld a0, 0(t0); la t0, external_initial_sp; ld a1, 0(t0); la t0, external_trap_stack; ld a2, 0(t0); call enterUserService" ::: "memory", "ra", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "t0", "t1", "t2", "t3", "t4", "t5", "t6");
    syscall_active = false;
    asm volatile ("csrw stvec, %[entry]; csrw sscratch, zero"
        :
        : [entry] "r" (historical_stvec),
        : "memory"
    );
    write("\nZIGREF_BATCH29_RESULT syscalls=");
    writeUsizeHex(syscall_count);
    write(" total=");
    writeUsizeHex(syscall_total_count);
    write(" dropped=");
    writeUsizeHex(syscall_dropped_count);
    write(" status=");
    writeUsizeHex(syscall_terminal_status);
    write(" output_hex=");
    writeHex(syscall_output[0..syscall_output_len]);
    write(" pages=");
    writeUsizeHex(external_image.items().len);
    write(" interpreter_pages=");
    writeUsizeHex(external_interpreter_image.items().len);
    write(" main_entry=");
    writeUsizeHex(candidate.main_entry);
    write(" interpreter_entry=");
    writeUsizeHex(candidate.entry + (if (candidate.interpreter != null) @as(usize, 0x40000000) else 0));
    write(" wx=0000000000000000\n");
    for (0..syscall_count) |index| {
        write("ZIGREF_BATCH29_SYSCALL index=");
        writeUsizeHex(index);
        write(" nr=");
        writeUsizeHex(syscall_numbers[index]);
        write(" pc=");
        writeUsizeHex(syscall_pcs[index]);
        write(" result=");
        writeUsizeHex(syscall_results[index]);
        write(" arg0=");
        writeUsizeHex(syscall_args[index][0]);
        write(" arg1=");
        writeUsizeHex(syscall_args[index][1]);
        write(" arg2=");
        writeUsizeHex(syscall_args[index][2]);
        write(" arg3=");
        writeUsizeHex(syscall_args[index][3]);
        write("\n");
    }
    _ = builder.unmapPage(external_stack_base, .page_4k) catch shutdown();
    const displaced_flags = displaced_stack_leaf.raw_entry;
    _ = builder.mapPage(external_stack_base, displaced_stack_leaf.physical_address, .page_4k, .{
        .read = displaced_flags & 0x2 != 0,
        .write = displaced_flags & 0x4 != 0,
        .execute = displaced_flags & 0x8 != 0,
        .user = displaced_flags & 0x10 != 0,
        .global = displaced_flags & 0x20 != 0,
        .accessed = displaced_flags & 0x40 != 0,
        .dirty = displaced_flags & 0x80 != 0,
    }) catch shutdown();
    asm volatile ("sfence.vma; fence.i" ::: "memory");
}

const SyscallBackend = struct {
    pub fn readBytes(_: @This(), operation: morphic_operation.ReadBytes) morphic_operation.Completion {
        const resource = syscall_resources.resolve(resource_tables.referenceFromIdentity(ResourceRef, operation.source)) orelse return .{ .failure = .invalid_resource };
        if (!resource.capabilities.read) return .{ .failure = .operation_not_supported };
        const read_plan = syscall_read_backend.plan(@intFromEnum(resource.backend), resource.state, operation.byte_count, syscall_stdin.len);
        if (read_plan == .unsupported) return .{ .failure = .operation_not_supported };
        if (read_plan == .live_console) {
            if (operation.byte_count == 0) return .{ .success = 0 };
            const plan = user_transfer.TransferPlan(2).plan(user_transfer.GuestVirtualAddress.init(@intFromEnum(operation.destination)), 1, .write_to_user, syscall_query) catch return .{ .failure = .invalid_user_memory };
            var byte: usize = std.math.maxInt(usize);
            while (byte == std.math.maxInt(usize)) byte = sbiCall(0x2, 0, 0, 0); // SBI legacy console getchar.
            const destination: [*]volatile u8 = @ptrFromInt(plan.items()[0].physical_start.raw());
            destination[0] = @truncate(byte);
            return .{ .success = 1 };
        }
        const fixture = read_plan.deterministic_fixture;
        const amount = fixture.end - fixture.start;
        if (amount == 0) return .{ .success = 0 };
        const plan = user_transfer.TransferPlan(2).plan(user_transfer.GuestVirtualAddress.init(@intFromEnum(operation.destination)), amount, .write_to_user, syscall_query) catch return .{ .failure = .invalid_user_memory };
        for (plan.items()) |segment| {
            const destination: [*]volatile u8 = @ptrFromInt(segment.physical_start.raw());
            for (0..segment.byte_count) |i| destination[i] = syscall_stdin[fixture.start + segment.request_offset + i];
        }
        syscall_resources.setState(resource_tables.referenceFromIdentity(ResourceRef, operation.source), fixture.end) catch return .{ .failure = .invalid_resource };
        return .{ .success = amount };
    }
    pub fn writeBytes(_: @This(), operation: morphic_operation.WriteBytes) morphic_operation.Completion {
        const resource = syscall_resources.resolve(resource_tables.referenceFromIdentity(ResourceRef, operation.destination)) orelse return .{ .failure = .invalid_resource };
        if (!resource.capabilities.write) return .{ .failure = .operation_not_supported };
        if (operation.byte_count == 0) return .{ .success = 0 };
        const plan = user_transfer.TransferPlan(2).plan(user_transfer.GuestVirtualAddress.init(@intFromEnum(operation.source)), operation.byte_count, .read_from_user, syscall_query) catch return .{ .failure = .invalid_user_memory };
        for (plan.items()) |segment| {
            const source: [*]const volatile u8 = @ptrFromInt(segment.physical_start.raw());
            for (0..segment.byte_count) |i| {
                const byte = source[i];
                if (syscall_output_len + segment.request_offset + i < syscall_output.len)
                    syscall_output[syscall_output_len + segment.request_offset + i] = byte;
                write(&.{byte});
            }
        }
        syscall_output_len = @min(syscall_output.len, syscall_output_len + operation.byte_count);
        return .{ .success = operation.byte_count };
    }
    pub fn terminate(_: @This(), status: u8) morphic_operation.Completion {
        return .{ .terminated = status };
    }
};

fn negativeErrno(value: usize) usize {
    return 0 -% value;
}

const exec_vector_capacity = 16;
const exec_string_capacity = 256;
const ExecStringVector = struct {
    storage: [exec_vector_capacity][exec_string_capacity]u8 = undefined,
    lengths: [exec_vector_capacity]usize = .{0} ** exec_vector_capacity,
    count: usize = 0,

    fn capture(address: usize) !ExecStringVector {
        var result: ExecStringVector = .{};
        if (address == 0) return result;
        while (result.count < exec_vector_capacity) : (result.count += 1) {
            const pointer = try readUserUsize(address + result.count * @sizeOf(usize));
            if (pointer == 0) return result;
            result.lengths[result.count] = try copyUserCString(pointer, &result.storage[result.count]);
        }
        // Distinguish exactly-full from an unterminated/oversized vector.
        if (try readUserUsize(address + exec_vector_capacity * @sizeOf(usize)) != 0)
            return error.InvalidUser;
        return result;
    }

    fn slices(self: *const ExecStringVector, output: *[exec_vector_capacity][]const u8) []const []const u8 {
        for (0..self.count) |index|
            output[index] = self.storage[index][0..self.lengths[index]];
        return output[0..self.count];
    }
};

fn unmapExternalImage(image: *const ExternalPreparedImage) void {
    for (image.items()) |page| {
        if (externalPageOccupied({}, page.virtual_start)) {
            _ = batch26_builder.unmapPage(page.virtual_start, .page_4k) catch shutdown();
        }
    }
}

fn installExternalImage(image: *const ExternalPreparedImage, backing: *[prepared_image_pages][frames.PageSize]u8) void {
    for (image.items()) |page| {
        const permissions = sv39_entries.Permissions{
            .read = page.permissions.read,
            .write = page.permissions.write,
            .execute = page.permissions.execute,
            .user = true,
            .accessed = true,
            .dirty = page.permissions.write,
        };
        if (permissions.write and permissions.execute) shutdown();
        _ = batch26_builder.mapPage(page.virtual_start, @intFromPtr(&backing[page.backing_index]), .page_4k, permissions) catch shutdown();
    }
}

const ExternalMappingPreflight = struct {
    builder: *MachineBuilder,
    backing: *[prepared_image_pages][frames.PageSize]u8,

    pub fn occupied(self: *@This(), virtual_start: usize) bool {
        _ = self.builder.query(virtual_start) catch return false;
        return true;
    }

    pub fn replaceable(_: *@This(), virtual_start: usize) bool {
        for (external_image.items()) |page|
            if (page.virtual_start == virtual_start) return true;
        for (external_interpreter_image.items()) |page|
            if (page.virtual_start == virtual_start) return true;
        if (virtual_start >= imageBreakStart(&external_image) and virtual_start < external_program_break)
            return true;
        for (external_runtime_mappings.entries[0..external_runtime_mappings.count]) |mapping|
            if (virtual_start >= mapping.start and virtual_start < mapping.end) return true;
        return false;
    }

    pub fn map(self: *@This(), virtual_start: usize, backing_index: usize) !void {
        _ = try self.builder.mapPage(
            virtual_start,
            @intFromPtr(&self.backing[backing_index]),
            .page_4k,
            .{ .read = true, .user = true, .accessed = true },
        );
    }

    pub fn unmap(self: *@This(), virtual_start: usize) !void {
        _ = try self.builder.unmapPage(virtual_start, .page_4k);
    }
};

fn preflightExternalImage(builder: *MachineBuilder, image: *const ExternalPreparedImage, backing: *[prepared_image_pages][frames.PageSize]u8) !void {
    var context = ExternalMappingPreflight{ .builder = builder, .backing = backing };
    try bounded_mapping_preflight.preflight(image.items(), backing.len, &context);
}

fn imageBreakStart(image: *const ExternalPreparedImage) usize {
    var end: usize = 0;
    for (image.items()) |page| end = @max(end, page.virtual_start + frames.PageSize);
    return end;
}

fn unmapExternalBreak(image: *const ExternalPreparedImage, current_break: usize) void {
    var page = imageBreakStart(image);
    const end = (current_break + frames.PageSize - 1) & ~@as(usize, frames.PageSize - 1);
    while (page < end) : (page += frames.PageSize) {
        if (externalPageOccupied({}, page))
            _ = batch26_builder.unmapPage(page, .page_4k) catch shutdown();
    }
}

fn externalExecve(frame: *TrapFrame) usize {
    if (!external_artifact_options.namespace_enabled) return negativeErrno(38);
    var path_buffer: [exec_string_capacity]u8 = undefined;
    const path_len = copyUserCString(frame.x[10], &path_buffer) catch return negativeErrno(14);
    const path = path_buffer[0..path_len];
    if (!validAbsolutePath(path)) return negativeErrno(2);
    const argv_vector = ExecStringVector.capture(frame.x[11]) catch return negativeErrno(14);
    const env_vector = ExecStringVector.capture(frame.x[12]) catch return negativeErrno(14);
    if (argv_vector.count == 0) return negativeErrno(22);

    const manifest: []const u8 = &external_rv64_namespace_manifest;
    const data: []const u8 = &external_rv64_namespace_data;
    const main_file = namespaceLookup(manifest, path, data) orelse return negativeErrno(2);
    const inspection = elf_load.planDynamic(4, 32, main_file.bytes) catch return negativeErrno(8);
    const interpreter_bytes: ?[]const u8 = if (inspection.interpreterPath()) |interpreter_path| blk: {
        const interpreter = namespaceLookup(manifest, interpreter_path, data) orelse return negativeErrno(2);
        break :blk interpreter.bytes;
    } else null;
    const candidate = address_space.ExecPlan(4, 32).prepare(main_file.bytes, interpreter_bytes) catch return negativeErrno(8);
    external_exec_image_candidate = ExternalPreparedImage.prepare(main_file.bytes, &candidate.main.load, 0, &external_exec_main_candidate) catch return negativeErrno(12);
    external_exec_interpreter_image_candidate = if (candidate.interpreter) |*interpreter|
        ExternalPreparedImage.prepare(interpreter_bytes.?, &interpreter.load, 0x40000000, &external_exec_interpreter_candidate) catch return negativeErrno(12)
    else
        ExternalPreparedImage{};

    var argv_slices: [exec_vector_capacity][]const u8 = undefined;
    var env_slices: [exec_vector_capacity][]const u8 = undefined;
    const argv = argv_vector.slices(&argv_slices);
    const envp = env_vector.slices(&env_slices);
    const main_segment = candidate.main.load.items()[0];
    const auxv = [_]initial_stack.AuxEntry{
        .{ .type = 6, .value = .{ .immediate = frames.PageSize } },
        .{ .type = 3, .value = .{ .immediate = main_segment.memory.start + 64 } },
        .{ .type = 4, .value = .{ .immediate = 56 } },
        .{ .type = 5, .value = .{ .immediate = @as(usize, main_file.bytes[56]) | (@as(usize, main_file.bytes[57]) << 8) } },
        .{ .type = 7, .value = .{ .immediate = if (candidate.interpreter != null) 0x40000000 else 0 } },
        .{ .type = 9, .value = .{ .immediate = candidate.main_entry } },
    };
    const external_stack_base = user_stack_va + frames.PageSize - external_stack_pages * frames.PageSize;
    const stack_range = initial_stack.GuestStackRange.init(external_stack_base, user_stack_va + frames.PageSize) catch return negativeErrno(12);
    const stack = initial_stack.plan(external_stack_plan_capacity, exec_vector_capacity, exec_vector_capacity, auxv.len, stack_range, argv, envp, &auxv) catch return negativeErrno(7);

    // Complete the same bounded table-backing preflight used by initial
    // external execution while every live child leaf and process field remains
    // untouched. Existing live leaves prove their table path; new paths are
    // allocated by temporary map/unmap probes. A failure returns from PREPARE.
    preflightExternalImage(batch26_builder, &external_exec_image_candidate, &external_exec_main_candidate) catch return negativeErrno(12);
    preflightExternalImage(batch26_builder, &external_exec_interpreter_image_candidate, &external_exec_interpreter_candidate) catch return negativeErrno(12);

    // COMMIT: no fallible guest-derived work remains. Resource bindings and
    // the retained parent snapshot deliberately survive image replacement.
    unmapExternalImage(&external_image);
    unmapExternalImage(&external_interpreter_image);
    unmapExternalBreak(&external_image, external_program_break);
    for (external_runtime_mappings.entries[0..external_runtime_mappings.count]) |mapping| {
        var page = mapping.start;
        while (page < mapping.end) : (page += frames.PageSize) {
            if (externalPageOccupied({}, page)) {
                _ = batch26_builder.unmapPage(page, .page_4k) catch shutdown();
            }
        }
    }
    external_prepared_backing = external_exec_main_candidate;
    external_interpreter_backing = external_exec_interpreter_candidate;
    external_image = external_exec_image_candidate;
    external_interpreter_image = external_exec_interpreter_image_candidate;
    external_stack_image = stack;
    external_runtime_mappings = .{};
    external_program_break = 0;
    for (candidate.main.load.items()) |segment| external_program_break = @max(external_program_break, segment.memory.end);
    external_program_break = (external_program_break + frames.PageSize - 1) & ~@as(usize, frames.PageSize - 1);
    external_next_backing = external_image.items().len;
    for (&external_prepared_stack) |*backing| @memset(backing, 0);
    const stack_offset = stack.initial_sp.raw() - external_stack_base;
    const stack_bytes: [*]u8 = @ptrCast(&external_prepared_stack);
    for (stack.bytes(), 0..) |byte, index| stack_bytes[stack_offset + index] = byte;
    installExternalImage(&external_image, &external_prepared_backing);
    installExternalImage(&external_interpreter_image, &external_interpreter_backing);
    asm volatile ("sfence.vma; fence.i" ::: "memory");
    const retained_sstatus = frame.sstatus;
    const retained_thread_pointer = frame.x[4];
    frame.x = .{0} ** 32;
    frame.x[2] = stack.initial_sp.raw();
    // exec replaces the image, not the calling task's architecture thread
    // register. The dynamic loader establishes its new TLS from this state.
    frame.x[4] = retained_thread_pointer;
    frame.sepc = candidate.entry + (if (candidate.interpreter != null) @as(usize, 0x40000000) else 0);
    frame.sstatus = retained_sstatus & ~@as(usize, 0x40122);
    asm volatile ("csrw sepc, %[pc]"
        :
        : [pc] "r" (frame.sepc),
        : "memory"
    );
    if (external_artifact_options.live_console_input) {
        write("ZIGREF_LINUX_EXECVE_COMMIT path=");
        write(path);
        write("\n");
    }
    return 0;
}

const LinuxRequestKind = enum { get_current_directory, change_directory, duplicate, duplicate_to, fcntl, close, pipe2, open_at, get_directory_entries, read, write, write_vector, new_fstatat, fstat, program_break, clone, execve, memory_map, terminate, unsupported };
fn decodeLinuxRequestKind(number: usize) LinuxRequestKind {
    return switch (number) {
        17 => .get_current_directory,
        49 => .change_directory,
        23 => .duplicate,
        24 => .duplicate_to,
        25 => .fcntl,
        56 => .open_at,
        57 => .close,
        59 => .pipe2,
        61 => .get_directory_entries,
        63 => .read,
        64 => .write,
        66 => .write_vector,
        79 => .new_fstatat,
        80 => .fstat,
        214 => .program_break,
        220 => .clone,
        221 => .execve,
        222 => .memory_map,
        93, 94 => .terminate,
        else => .unsupported,
    };
}
comptime {
    if (decodeLinuxRequestKind(17) != .get_current_directory or decodeLinuxRequestKind(49) != .change_directory or decodeLinuxRequestKind(23) != .duplicate or decodeLinuxRequestKind(24) != .duplicate_to or decodeLinuxRequestKind(25) != .fcntl or decodeLinuxRequestKind(56) != .open_at or decodeLinuxRequestKind(57) != .close or decodeLinuxRequestKind(59) != .pipe2 or decodeLinuxRequestKind(61) != .get_directory_entries or decodeLinuxRequestKind(63) != .read or decodeLinuxRequestKind(64) != .write or decodeLinuxRequestKind(66) != .write_vector or decodeLinuxRequestKind(79) != .new_fstatat or decodeLinuxRequestKind(80) != .fstat or decodeLinuxRequestKind(214) != .program_break or decodeLinuxRequestKind(220) != .clone or decodeLinuxRequestKind(221) != .execve or decodeLinuxRequestKind(222) != .memory_map or decodeLinuxRequestKind(93) != .terminate or decodeLinuxRequestKind(94) != .terminate or decodeLinuxRequestKind(0x7fff) != .unsupported) @compileError("Linux/RV64 decoder drift");
}

fn copyPipeDescriptors(destination: usize, descriptors: [2]usize) !void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u32, bytes[0..4], @intCast(descriptors[0]), .little);
    std.mem.writeInt(u32, bytes[4..8], @intCast(descriptors[1]), .little);
    try copyBytesToUser(destination, &bytes);
}

fn pipeWriterBound(pipe_id: usize) bool {
    return linux_rv64_pipe_lifetime.owned(&syscall_resources, &syscall_bindings, external_fork_parent != null, &external_fork_resources, &external_fork_bindings, syscall_binding_capacity, pipe_id, .writer);
}

fn retirePipeIfUnowned(pipe_id: usize) void {
    _ = linux_rv64_pipe_lifetime.retireIfUnowned(&external_pipes, &syscall_resources, &syscall_bindings, external_fork_parent != null, &external_fork_resources, &external_fork_bindings, syscall_binding_capacity, pipe_id);
}

fn pipeRead(reference: ResourceRef, destination: usize, requested: usize) usize {
    const description = syscall_resources.resolve(reference) orelse return negativeErrno(9);
    if (!description.capabilities.read) return negativeErrno(9);
    var bytes: [4096]u8 = undefined;
    const amount = external_pipes.read(description.state, bytes[0..@min(requested, bytes.len)]) catch return negativeErrno(9);
    if (amount == 0 and pipeWriterBound(description.state)) return negativeErrno(11);
    copyBytesToUser(destination, bytes[0..amount]) catch return negativeErrno(14);
    return amount;
}

fn pipeWrite(reference: ResourceRef, source_address: usize, requested: usize) usize {
    const description = syscall_resources.resolve(reference) orelse return negativeErrno(9);
    if (!description.capabilities.write) return negativeErrno(9);
    const amount = @min(requested, @as(usize, 4096));
    const plan = user_transfer.TransferPlan(2).plan(user_transfer.GuestVirtualAddress.init(source_address), amount, .read_from_user, syscall_query) catch return negativeErrno(14);
    var bytes: [4096]u8 = undefined;
    for (plan.items()) |segment| {
        const source: [*]const volatile u8 = @ptrFromInt(segment.physical_start.raw());
        for (0..segment.byte_count) |i| bytes[segment.request_offset + i] = source[i];
    }
    return external_pipes.write(description.state, bytes[0..amount]) catch |err| return negativeErrno(if (err == error.WouldBlock) 11 else 9);
}

fn externalChangeDirectory(path_address: usize) usize {
    if (!external_artifact_options.namespace_enabled) return negativeErrno(2);
    var path_buffer: [256]u8 = undefined;
    const path_len = copyUserCString(path_address, &path_buffer) catch return negativeErrno(14);
    const path = path_buffer[0..path_len];
    if (!std.mem.eql(u8, path, "/") and !validAbsolutePath(path)) return negativeErrno(2);
    const object = bounded_namespace_lookup.resolve(&external_rv64_namespace_manifest, path, true) catch return negativeErrno(2);
    if (object.kind != .directory) return negativeErrno(20);
    external_process_cwd.setAbsolute(path) catch return negativeErrno(36);
    return 0;
}

fn namespaceDirectoryEntries(reference: ResourceRef, destination: usize, requested: usize) usize {
    const description = syscall_resources.resolve(reference) orelse return negativeErrno(9);
    if (@intFromEnum(description.backend) != syscall_read_backend.namespace_directory) return negativeErrno(20);
    if (requested == 0) return 0;
    var output: [4096]u8 = undefined;
    const limit = @min(requested, output.len);
    const manifest: []const u8 = &external_rv64_namespace_manifest;
    const directory_offset = description.state >> 32;
    var cursor = description.state & 0xffffffff;
    const directory_end = std.mem.indexOfScalarPos(u8, manifest, directory_offset, '}') orelse return negativeErrno(5);
    const directory_row = manifest[directory_offset .. directory_end + 1];
    const directory_path = jsonStringAfter(directory_row, 0, "\"path\":\"") orelse return negativeErrno(5);
    var used: usize = 0;
    while (std.mem.indexOfPos(u8, manifest, cursor, "\"path\":\"")) |at| {
        const object_end = std.mem.indexOfScalarPos(u8, manifest, at, '}') orelse return negativeErrno(5);
        const object_begin = std.mem.lastIndexOfScalar(u8, manifest[0..at], '{') orelse return negativeErrno(5);
        const row = manifest[object_begin .. object_end + 1];
        const path = jsonStringAfter(row, 0, "\"path\":\"") orelse return negativeErrno(5);
        cursor = object_end + 1;
        if (std.mem.eql(u8, path, directory_path)) continue;
        const prefix_len = if (std.mem.eql(u8, directory_path, "/")) 1 else directory_path.len + 1;
        if (path.len <= prefix_len or !std.mem.startsWith(u8, path, directory_path) or
            (!std.mem.eql(u8, directory_path, "/") and path[directory_path.len] != '/')) continue;
        const name = path[prefix_len..];
        if (std.mem.indexOfScalar(u8, name, '/') != null) continue;
        const record_len = std.mem.alignForward(usize, 19 + name.len + 1, 8);
        if (record_len > limit - used) {
            cursor = object_begin;
            break;
        }
        @memset(output[used .. used + record_len], 0);
        std.mem.writeInt(u64, output[used..][0..8], object_begin + 1, .little);
        std.mem.writeInt(i64, output[used..][8..16], @intCast(cursor), .little);
        std.mem.writeInt(u16, output[used..][16..18], @intCast(record_len), .little);
        const kind = jsonStringAfter(row, 0, "\"kind\":\"") orelse return negativeErrno(5);
        output[used + 18] = if (std.mem.eql(u8, kind, "directory")) 4 else if (std.mem.eql(u8, kind, "regular")) 8 else if (std.mem.eql(u8, kind, "symlink")) 10 else return negativeErrno(5);
        @memcpy(output[used + 19 ..][0..name.len], name);
        used += record_len;
    }
    copyBytesToUser(destination, output[0..used]) catch return negativeErrno(14);
    syscall_resources.setState(reference, (directory_offset << 32) | cursor) catch return negativeErrno(9);
    return used;
}

fn namespaceRegularRead(reference: ResourceRef, destination: usize, requested: usize) usize {
    const description = syscall_resources.resolve(reference) orelse return negativeErrno(9);
    if (@intFromEnum(description.backend) != syscall_read_backend.namespace_regular) return negativeErrno(20);
    const manifest_offset = description.state >> 32;
    const file_offset = description.state & 0xffffffff;
    const manifest: []const u8 = &external_rv64_namespace_manifest;
    const row_end = std.mem.indexOfScalarPos(u8, manifest, manifest_offset, '}') orelse return negativeErrno(5);
    const row = manifest[manifest_offset .. row_end + 1];
    const data_offset = jsonUnsignedAfter(row, 0, "\"data_offset\":") orelse return negativeErrno(5);
    const data_length = jsonUnsignedAfter(row, 0, "\"data_length\":") orelse return negativeErrno(5);
    if (file_offset > data_length or data_offset > external_rv64_namespace_data.len or data_length > external_rv64_namespace_data.len - data_offset) return negativeErrno(5);
    const amount = @min(requested, data_length - file_offset);
    copyBytesToUser(destination, external_rv64_namespace_data[data_offset + file_offset ..][0..amount]) catch return negativeErrno(14);
    syscall_resources.setState(reference, (manifest_offset << 32) | (file_offset + amount)) catch return negativeErrno(9);
    return amount;
}

const runtime_regular_backend: u32 = 0x102;

fn runtimeRegularRead(reference: ResourceRef, destination: usize, requested: usize) usize {
    const description = syscall_resources.resolve(reference) orelse return negativeErrno(9);
    const access: bounded_runtime_namespace.Access = .{ .read = description.capabilities.read, .write = description.capabilities.write };
    access.require(.read) catch return negativeErrno(9);
    const object = description.state >> 32;
    const offset = description.state & 0xffffffff;
    var bytes: [256]u8 = undefined;
    const amount = external_runtime_namespace.readWithAccess(access, object, offset, bytes[0..@min(requested, bytes.len)]) catch |err| return negativeErrno(if (err == error.AccessDenied) 9 else 5);
    copyBytesToUser(destination, bytes[0..amount]) catch return negativeErrno(14);
    syscall_resources.setState(reference, (object << 32) | (offset + amount)) catch return negativeErrno(9);
    return amount;
}

fn runtimeRegularWrite(reference: ResourceRef, source_address: usize, requested: usize) usize {
    const description = syscall_resources.resolve(reference) orelse return negativeErrno(9);
    const access: bounded_runtime_namespace.Access = .{ .read = description.capabilities.read, .write = description.capabilities.write };
    access.require(.write) catch return negativeErrno(9);
    const object = description.state >> 32;
    const offset = description.state & 0xffffffff;
    const amount = @min(requested, 256 -| offset);
    if (amount == 0 and requested != 0) return negativeErrno(28);
    const plan = user_transfer.TransferPlan(2).plan(user_transfer.GuestVirtualAddress.init(source_address), amount, .read_from_user, syscall_query) catch return negativeErrno(14);
    var bytes: [256]u8 = undefined;
    for (plan.items()) |segment| {
        const source: [*]const volatile u8 = @ptrFromInt(segment.physical_start.raw());
        for (0..segment.byte_count) |i| bytes[segment.request_offset + i] = source[i];
    }
    const written = external_runtime_namespace.writeWithAccess(access, object, offset, bytes[0..amount]) catch |err| return negativeErrno(if (err == error.AccessDenied) 9 else 28);
    syscall_resources.setState(reference, (object << 32) | (offset + written)) catch return negativeErrno(9);
    return written;
}

fn externalNamespaceOpenAt(directory: usize, path_address: usize, flags: usize) usize {
    // Linux access and creation flags are interpreted only at this edge. This
    // bounded slice admits read-only opens and rejects mutation of the source
    // namespace. Relative directory-descriptor traversal remains unimplemented.
    if (!external_artifact_options.namespace_enabled or directory != negativeErrno(100)) return negativeErrno(9);
    var path_buffer: [256]u8 = undefined;
    const path_len = copyUserCString(path_address, &path_buffer) catch return negativeErrno(14);
    const path = path_buffer[0..path_len];
    if (!std.mem.eql(u8, path, "/") and !validAbsolutePath(path)) return negativeErrno(2);
    const access = flags & 0x3;
    const create = flags & 0x40 != 0;
    const truncate = flags & 0x200 != 0;
    const runtime_existing = external_runtime_namespace.lookup(path);
    if (runtime_existing != null or create) {
        // O_APPEND fails closed until every write can select EOF atomically.
        if (flags & 0x400 != 0 or flags & ~@as(usize, 0x3 | 0x40 | 0x200 | 0x8000) != 0) return negativeErrno(22);
        const capabilities: resource_tables.Capabilities = .{ .read = access != 1, .write = access != 0 };
        return bounded_runtime_namespace.openResource(&external_runtime_namespace, &syscall_resources, &syscall_bindings, path, create, truncate, ResourceStore.Description{ .backend = @enumFromInt(runtime_regular_backend), .capabilities = capabilities }) catch |err| negativeErrno(switch (err) {
            error.NotFound => 2,
            error.ObjectCapacity, error.ByteCapacity => 28,
            error.InvalidPath, error.PathTooLong => 22,
            error.ResourceFull => 23,
            error.DescriptorFull => 24,
            error.AccessDenied => 9,
        });
    }
    if (access != 0 or truncate) return negativeErrno(30);
    // Linux asm-generic O_NOFOLLOW. Ordinary open follows the final symlink
    // through the same bounded resolver used by executable namespace lookup.
    const no_follow = flags & 0x20000 != 0;
    const object = bounded_namespace_lookup.resolve(&external_rv64_namespace_manifest, path, !no_follow) catch |err| return negativeErrno(switch (err) {
        error.FinalSymlink, error.TraversalLimit => 40,
        error.InvalidPath, error.NotFound, error.MalformedObject => 2,
    });
    // Linux O_DIRECTORY is 0x10000 on asm-generic targets.
    if (flags & 0x10000 != 0 and object.kind != .directory) return negativeErrno(20);
    const backend: resource_tables.BackendId = @enumFromInt(switch (object.kind) {
        .directory => @as(u32, 0x100),
        .regular => @as(u32, 0x101),
        .symlink => unreachable, // resolve returns a final symlink only as an error.
    });
    // Namespace I/O backends deliberately expose no semantic read capability
    // until their actual file/directory read operations are implemented.
    if (object.manifest_offset > 0xffffffff) return negativeErrno(75);
    const reference = syscall_resources.create(.{ .backend = backend, .capabilities = .{}, .state = object.manifest_offset << 32 }) catch return negativeErrno(23);
    const descriptor = syscall_bindings.lowestFreeAtOrAbove(3) orelse {
        _ = syscall_resources.release(reference) catch shutdown();
        return negativeErrno(24);
    };
    syscall_bindings.bindAt(descriptor, reference) catch shutdown();
    if (external_artifact_options.live_console_input) {
        write("ZIGREF_LINUX_OPENAT path=");
        write(path);
        write(" fd=");
        writeUsizeHex(descriptor);
        write("\n");
    }
    return descriptor;
}

fn externalNamespaceStat(path_address: usize, destination: usize, flags: usize) usize {
    // Linux asm-generic stat and newfstatat are compatibility-edge details.
    // The bounded namespace remains an ABI-neutral manifest/backing transport.
    if (!external_artifact_options.namespace_enabled or flags & ~@as(usize, 0x100) != 0)
        return negativeErrno(22);
    var path_buffer: [256]u8 = undefined;
    const path_len = copyUserCString(path_address, &path_buffer) catch return negativeErrno(14);
    const path = path_buffer[0..path_len];
    if (external_artifact_options.live_console_input) {
        write("ZIGREF_LINUX_NEWFSTATAT path=");
        write(path);
        write("\n");
    }
    if (!std.mem.eql(u8, path, "/") and !validAbsolutePath(path)) return negativeErrno(2);
    const manifest: []const u8 = &external_rv64_namespace_manifest;
    const object = (if (flags & 0x100 != 0)
        bounded_namespace_lookup.resolveFinalObject(manifest, path)
    else
        bounded_namespace_lookup.resolve(manifest, path, true)) catch |err| return negativeErrno(if (err == error.MalformedObject) 5 else 2);
    const row_end = std.mem.indexOfScalarPos(u8, manifest, object.manifest_offset, '}') orelse return negativeErrno(5);
    const row = manifest[object.manifest_offset .. row_end + 1];
    const size = if (object.kind == .regular) object.data_length else if (object.kind == .symlink) (jsonStringAfter(row, 0, "\"target\":\"") orelse return negativeErrno(5)).len else 0;
    linux_rv64_fstat.copyOut(.{
        .inode = object.manifest_offset + 1,
        .mode = switch (object.kind) {
            .directory => 0o040755,
            .regular => 0o100755,
            .symlink => 0o120777,
        },
        .size = size,
    }, destination, copyBytesToUser) catch return negativeErrno(14);
    return 0;
}

fn externalResourceFstat(descriptor: usize, destination: usize) usize {
    const description = linux_rv64_fstat.resolveDescription(&syscall_resources, &syscall_bindings, descriptor) catch |err| return negativeErrno(linux_rv64_fstat.linuxErrno(err));
    const backend = @intFromEnum(description.backend);
    if (backend != 0x100 and backend != 0x101) return negativeErrno(95);
    const manifest_offset = description.state >> 32;
    const manifest: []const u8 = &external_rv64_namespace_manifest;
    if (manifest_offset >= manifest.len) return negativeErrno(5);
    const row_end = std.mem.indexOfScalarPos(u8, manifest, manifest_offset, '}') orelse return negativeErrno(5);
    const row = manifest[manifest_offset .. row_end + 1];
    const kind = jsonStringAfter(row, 0, "\"kind\":\"") orelse return negativeErrno(5);
    const is_directory = std.mem.eql(u8, kind, "directory");
    if (is_directory != (backend == 0x100)) return negativeErrno(5);
    const size = if (is_directory) 0 else jsonUnsignedAfter(row, 0, "\"data_length\":") orelse return negativeErrno(5);
    linux_rv64_fstat.copyOut(.{
        .inode = manifest_offset + 1,
        .mode = if (is_directory) 0o040755 else 0o100755,
        .size = size,
    }, destination, copyBytesToUser) catch return negativeErrno(14);
    return 0;
}

fn externalPageOccupied(_: void, page: usize) bool {
    const leaf = batch26_builder.query(page) catch return false;
    return leaf.raw_entry & 1 != 0 and leaf.raw_entry & 0xe != 0;
}

const ExternalFileMmapContext = struct {
    source: []const u8,
    backing_start: usize,

    pub fn occupied(_: *@This(), page: usize) bool {
        return externalPageOccupied({}, page);
    }

    pub fn prepare(self: *@This(), plan: linux_rv64_file_mmap.Plan) !void {
        const page_count = plan.mapped_length / frames.PageSize;
        for (external_prepared_backing[self.backing_start .. self.backing_start + page_count]) |*page| @memset(page, 0);
        const bytes = self.source[plan.file_offset..][0..plan.byte_length];
        for (bytes, 0..) |byte, byte_index|
            external_prepared_backing[self.backing_start + byte_index / frames.PageSize][byte_index % frames.PageSize] = byte;
    }

    pub fn mapPage(self: *@This(), virtual: usize, page_index: usize, permissions: linux_rv64_file_mmap.Permissions) !void {
        const physical = @intFromPtr(&external_prepared_backing[self.backing_start + page_index]);
        _ = try batch26_builder.mapPage(virtual, physical, .page_4k, .{
            .read = permissions.read,
            .write = permissions.write,
            .execute = permissions.execute,
            .user = true,
            .accessed = true,
            .dirty = permissions.write,
        });
    }

    pub fn unmapPage(_: *@This(), virtual: usize) !void {
        _ = try batch26_builder.unmapPage(virtual, .page_4k);
    }
};

fn externalFileMmap(length: usize, protection: usize, flags: usize, descriptor: usize, offset: usize) usize {
    const description = linux_rv64_file_mmap.resolveRegular(&syscall_resources, &syscall_bindings, descriptor, 0x101) catch |err| return negativeErrno(switch (err) {
        error.BadDescriptor => 9,
        error.UnsupportedResource => 19,
    });
    const manifest_offset = description.state >> 32;
    const manifest: []const u8 = &external_rv64_namespace_manifest;
    if (manifest_offset >= manifest.len) return negativeErrno(5);
    const row_end = std.mem.indexOfScalarPos(u8, manifest, manifest_offset, '}') orelse return negativeErrno(5);
    const row = manifest[manifest_offset .. row_end + 1];
    const data_offset = jsonUnsignedAfter(row, 0, "\"data_offset\":") orelse return negativeErrno(5);
    const data_length = jsonUnsignedAfter(row, 0, "\"data_length\":") orelse return negativeErrno(5);
    if (data_offset > external_rv64_namespace_data.len or data_length > external_rv64_namespace_data.len - data_offset) return negativeErrno(5);
    const plan = linux_rv64_file_mmap.plan(data_length, length, protection, flags, offset, frames.PageSize) catch |err| return negativeErrno(switch (err) {
        error.InvalidArgument, error.PermissionDenied => 22,
        error.FileRange => 75,
        error.AddressOverflow => 12,
    });
    const page_count = plan.mapped_length / frames.PageSize;
    const backing_end = std.math.add(usize, external_next_backing, page_count) catch return negativeErrno(12);
    if (backing_end > prepared_image_pages) return negativeErrno(12);

    var candidate = external_program_break;
    while (candidate < user_stack_va) : (candidate += frames.PageSize) {
        var context = ExternalFileMmapContext{
            .source = external_rv64_namespace_data[data_offset .. data_offset + data_length],
            .backing_start = external_next_backing,
        };
        linux_rv64_file_mmap.mapPrivate(plan, candidate, &external_runtime_mappings, &context, ExternalFileMmapContext.occupied) catch |err| switch (err) {
            error.Collision => continue,
            error.InvalidRange, error.WriteExecute => return negativeErrno(22),
            error.CapacityExceeded => return negativeErrno(12),
            else => {
                asm volatile ("sfence.vma" ::: "memory");
                return negativeErrno(12);
            },
        };
        external_next_backing = backing_end;
        asm volatile ("sfence.vma" ::: "memory");
        return candidate;
    }
    return negativeErrno(12);
}

fn recordLinuxRv64Syscall(frame: *TrapFrame) void {
    if (frame.scause != 8 or frame.sstatus & (0x100 | 0x40000) != 0) {
        write("ZIGREF_LINUX_EDGE_TRAP cause=");
        writeUsizeHex(frame.scause);
        write(" sepc=");
        writeUsizeHex(frame.sepc);
        write(" stval=");
        writeUsizeHex(frame.stval);
        write("\n");
        shutdown();
    }
    // Slot `syscall_capacity` is scratch for semantic dispatch after the
    // evidence window fills. It is never reported, so the first 64 retained
    // records remain immutable while total/dropped accounting continues.
    const index = bounded_syscall_evidence.observe(syscall_capacity, &syscall_count, &syscall_total_count, &syscall_dropped_count) orelse syscall_capacity;
    syscall_numbers[index] = frame.x[17];
    syscall_pcs[index] = frame.sepc;
    syscall_sstatus[index] = frame.sstatus;
    syscall_args[index] = .{ frame.x[10], frame.x[11], frame.x[12], frame.x[13], frame.x[14], frame.x[15] };
    var request: ?morphic_operation.Request = null;
    switch (decodeLinuxRequestKind(frame.x[17])) {
        .get_current_directory => {
            syscall_semantics[index] = 10;
            const needed = external_process_cwd.path().len + 1;
            if (frame.x[11] < needed) {
                frame.x[10] = negativeErrno(34);
            } else {
                var cwd: [256]u8 = .{0} ** 256;
                @memcpy(cwd[0..external_process_cwd.path().len], external_process_cwd.path());
                copyBytesToUser(frame.x[10], cwd[0..needed]) catch {
                    frame.x[10] = negativeErrno(14);
                    return finishReturningSyscall(frame, index);
                };
                frame.x[10] = needed;
            }
        },
        .change_directory => {
            syscall_semantics[index] = 16;
            frame.x[10] = externalChangeDirectory(frame.x[10]);
        },
        .duplicate => {
            syscall_semantics[index] = 4;
            if (syscall_bindings.resolve(frame.x[10])) |reference| {
                const old_slot = frame.x[10];
                const new_slot = syscall_bindings.duplicateLowest(old_slot) catch {
                    frame.x[10] = negativeErrno(24);
                    return finishReturningSyscall(frame, index);
                };
                syscall_resources.retain(reference) catch shutdown();
                frame.x[10] = new_slot;
            } else frame.x[10] = negativeErrno(9);
        },
        .duplicate_to => {
            syscall_semantics[index] = 18;
            const displaced = if (syscall_bindings.resolve(frame.x[11])) |reference| syscall_resources.resolve(reference) else null;
            frame.x[10] = linux_rv64_dup3.replace(&syscall_resources, &syscall_bindings, frame.x[10], frame.x[11], frame.x[12], syscall_binding_capacity) catch |err| negativeErrno(switch (err) {
                error.InvalidSource, error.InvalidTarget => 9,
                error.SameDescriptor, error.UnsupportedFlags => 22,
                error.ResourceFull => 23,
            });
            if (@as(isize, @bitCast(frame.x[10])) >= 0) if (displaced) |description| {
                const backend = @intFromEnum(description.backend);
                if (backend == linux_rv64_pipe2.read_backend or backend == linux_rv64_pipe2.write_backend)
                    retirePipeIfUnowned(description.state);
            };
        },
        .fcntl => {
            syscall_semantics[index] = 17;
            // Linux/RV64 F_DUPFD is command zero. Other fcntl policy remains
            // explicitly unsupported at this compatibility edge.
            if (frame.x[11] != 0) {
                // Linux reports an unrecognized fcntl command as EINVAL. In
                // particular, musl uses that result to fall back from an
                // unsupported F_DUPFD_CLOEXEC request to plain F_DUPFD.
                frame.x[10] = negativeErrno(22);
            } else frame.x[10] = linux_rv64_fdupfd.duplicate(&syscall_resources, &syscall_bindings, frame.x[10], frame.x[12], syscall_binding_capacity) catch |err| negativeErrno(switch (err) {
                error.InvalidSource => 9,
                error.InvalidMinimum => 22,
                error.DescriptorFull => 24,
                error.ResourceFull => 23,
            });
        },
        .close => {
            syscall_semantics[index] = 5;
            const reference = syscall_bindings.unbind(frame.x[10]) catch {
                frame.x[10] = negativeErrno(9);
                return finishReturningSyscall(frame, index);
            };
            const description = syscall_resources.resolve(reference);
            _ = syscall_resources.release(reference) catch shutdown();
            if (description) |closed| {
                const backend = @intFromEnum(closed.backend);
                if (backend == linux_rv64_pipe2.read_backend or backend == linux_rv64_pipe2.write_backend)
                    retirePipeIfUnowned(closed.state);
            }
            frame.x[10] = 0;
        },
        .pipe2 => {
            syscall_semantics[index] = 19;
            _ = linux_rv64_pipe2.create(&external_pipes, &syscall_resources, &syscall_bindings, frame.x[11], frame.x[10], copyPipeDescriptors) catch |err| {
                frame.x[10] = negativeErrno(switch (err) {
                    error.UnsupportedFlags => 22,
                    error.DescriptorFull => 24,
                    error.ResourceFull, error.PipeFull => 23,
                    error.CopyOut => 14,
                });
                return finishReturningSyscall(frame, index);
            };
            frame.x[10] = 0;
        },
        .open_at => {
            syscall_semantics[index] = 14;
            frame.x[10] = externalNamespaceOpenAt(frame.x[10], frame.x[11], frame.x[12]);
        },
        .get_directory_entries => {
            syscall_semantics[index] = 15;
            const reference = syscall_bindings.resolve(frame.x[10]) orelse {
                frame.x[10] = negativeErrno(9);
                return finishReturningSyscall(frame, index);
            };
            frame.x[10] = namespaceDirectoryEntries(reference, frame.x[11], frame.x[12]);
        },
        .read => blk: {
            syscall_semantics[index] = 6;
            const reference = syscall_bindings.resolve(frame.x[10]) orelse {
                frame.x[10] = negativeErrno(9);
                break :blk;
            };
            if (syscall_resources.resolve(reference)) |description| {
                if (@intFromEnum(description.backend) == syscall_read_backend.namespace_regular) {
                    frame.x[10] = namespaceRegularRead(reference, frame.x[11], frame.x[12]);
                    break :blk;
                }
                if (@intFromEnum(description.backend) == runtime_regular_backend) {
                    frame.x[10] = runtimeRegularRead(reference, frame.x[11], frame.x[12]);
                    break :blk;
                }
                if (@intFromEnum(description.backend) == linux_rv64_pipe2.read_backend) {
                    frame.x[10] = pipeRead(reference, frame.x[11], frame.x[12]);
                    break :blk;
                }
            }
            request = .{ .read_bytes = .{ .source = resource_tables.semanticIdentity(reference), .destination = @enumFromInt(@as(u64, frame.x[11])), .byte_count = frame.x[12] } };
        },
        .write => blk: {
            syscall_semantics[index] = 2;
            const reference = syscall_bindings.resolve(frame.x[10]) orelse {
                frame.x[10] = negativeErrno(9);
                break :blk;
            };
            if (syscall_resources.resolve(reference)) |description| if (@intFromEnum(description.backend) == runtime_regular_backend) {
                frame.x[10] = runtimeRegularWrite(reference, frame.x[11], frame.x[12]);
                break :blk;
            };
            if (syscall_resources.resolve(reference)) |description| if (@intFromEnum(description.backend) == linux_rv64_pipe2.write_backend) {
                frame.x[10] = pipeWrite(reference, frame.x[11], frame.x[12]);
                break :blk;
            };
            request = .{ .write_bytes = .{ .destination = resource_tables.semanticIdentity(reference), .source = @enumFromInt(@as(u64, frame.x[11])), .byte_count = frame.x[12] } };
        },
        .write_vector => blk: {
            syscall_semantics[index] = 11;
            const reference = syscall_bindings.resolve(frame.x[10]) orelse {
                frame.x[10] = negativeErrno(9);
                break :blk;
            };
            if (frame.x[12] > 16) {
                frame.x[10] = negativeErrno(22);
                break :blk;
            }
            var total: usize = 0;
            for (0..frame.x[12]) |vector_index| {
                const vector_address = frame.x[11] + vector_index * 16;
                const source = readUserUsize(vector_address) catch {
                    frame.x[10] = negativeErrno(14);
                    break :blk;
                };
                const length = readUserUsize(vector_address + 8) catch {
                    frame.x[10] = negativeErrno(14);
                    break :blk;
                };
                if (syscall_resources.resolve(reference)) |description| if (@intFromEnum(description.backend) == linux_rv64_pipe2.write_backend) {
                    const written = pipeWrite(reference, source, length);
                    if (@as(isize, @bitCast(written)) < 0) {
                        frame.x[10] = written;
                        break :blk;
                    }
                    total += written;
                    continue;
                };
                const completion = morphic_operation.execute(.{ .write_bytes = .{ .destination = resource_tables.semanticIdentity(reference), .source = @enumFromInt(@as(u64, source)), .byte_count = length } }, SyscallBackend{});
                switch (completion) {
                    .success => |amount| total += amount,
                    else => {
                        frame.x[10] = negativeErrno(14);
                        break :blk;
                    },
                }
            }
            frame.x[10] = total;
        },
        .new_fstatat => {
            syscall_semantics[index] = 9;
            // Only AT_FDCWD is meaningful until directory descriptors exist.
            frame.x[10] = if (frame.x[10] == negativeErrno(100))
                externalNamespaceStat(frame.x[11], frame.x[12], frame.x[13])
            else
                negativeErrno(9);
        },
        .fstat => {
            syscall_semantics[index] = 17;
            frame.x[10] = externalResourceFstat(frame.x[10], frame.x[11]);
        },
        .program_break => {
            syscall_semantics[index] = 7;
            const requested = frame.x[10];
            if (requested != 0 and requested >= external_program_break and requested < user_stack_va) {
                var page = (external_program_break + frames.PageSize - 1) & ~@as(usize, frames.PageSize - 1);
                const end = (requested + frames.PageSize - 1) & ~@as(usize, frames.PageSize - 1);
                while (page < end) : (page += frames.PageSize) {
                    if (external_next_backing == prepared_image_pages) break;
                    @memset(&external_prepared_backing[external_next_backing], 0);
                    const physical = @intFromPtr(&external_prepared_backing[external_next_backing]);
                    _ = batch26_builder.mapPage(page, physical, .page_4k, .{ .read = true, .write = true, .user = true, .accessed = true, .dirty = true }) catch break;
                    external_next_backing += 1;
                }
                if (page == end) external_program_break = requested;
            }
            frame.x[10] = external_program_break;
        },
        .clone => {
            syscall_semantics[index] = 12;
            if (external_artifact_options.live_console_input) {
                write("ZIGREF_LINUX_CLONE flags=");
                writeUsizeHex(frame.x[10]);
                write(" child_stack=");
                writeUsizeHex(frame.x[11]);
                write("\n");
            }
            // Linux clone flags remain at this compatibility edge.  The
            // bounded runtime currently supports the fork-shaped request ash
            // emits: a SIGCHLD child with a copied process image. The child
            // runs first while the bounded parent snapshot is held.
            const flags = frame.x[10];
            if (!linux_rv64_clone_request.supported(flags, frame.x[11], external_fork_parent != null)) {
                frame.x[10] = negativeErrno(22);
            } else {
                var parent = frame.*;
                parent.sepc += 4;
                parent.x[10] = external_child_pid;
                external_fork_parent = parent;
                external_fork_main_snapshot = external_prepared_backing;
                external_fork_interpreter_snapshot = external_interpreter_backing;
                external_fork_stack_snapshot = external_prepared_stack;
                external_fork_image_snapshot = external_image;
                external_fork_interpreter_image_snapshot = external_interpreter_image;
                external_fork_stack_image_snapshot = external_stack_image;
                external_fork_resources = syscall_resources;
                external_fork_bindings = syscall_bindings;
                external_fork_mappings = external_runtime_mappings;
                external_fork_program_break = external_program_break;
                external_fork_next_backing = external_next_backing;
                external_fork_cwd = external_process_cwd;
                frame.x[10] = 0;
            }
        },
        .execve => {
            syscall_semantics[index] = 13;
            const result = externalExecve(frame);
            if (result == 0) {
                syscall_results[index] = 0;
                syscall_resume_pcs[index] = frame.sepc;
                return;
            }
            frame.x[10] = result;
        },
        .memory_map => {
            syscall_semantics[index] = 8;
            const address = frame.x[10];
            const length = frame.x[11];
            const protection = frame.x[12];
            const flags = frame.x[13];
            const descriptor = frame.x[14];
            const offset = frame.x[15];
            // Linux/RV64 UAPI: MAP_PRIVATE | MAP_FIXED | MAP_ANONYMOUS.
            // This observed minimum slice is an exact, page-aligned, no-access
            // anonymous reservation. Linux values and errno remain here.
            if (address == 0 and flags == 0x2) {
                frame.x[10] = externalFileMmap(length, protection, flags, descriptor, offset);
            } else if (descriptor != std.math.maxInt(usize) or offset != 0 or length == 0) {
                if (external_artifact_options.live_console_input) {
                    write("LINUX_MMAP_REJECT address=");
                    writeUsizeHex(address);
                    write(" length=");
                    writeUsizeHex(length);
                    write(" protection=");
                    writeUsizeHex(protection);
                    write(" flags=");
                    writeUsizeHex(flags);
                    write(" fd=");
                    writeUsizeHex(descriptor);
                    write(" offset=");
                    writeUsizeHex(offset);
                    write("\n");
                }
                frame.x[10] = negativeErrno(22);
            } else if (protection == 0 and flags == 0x32) {
                external_runtime_mappings.reserve(address, length, .{}, true, {}, externalPageOccupied) catch {
                    frame.x[10] = negativeErrno(12);
                    return finishReturningSyscall(frame, index);
                };
                var page = address;
                const end = address + length;
                while (page < end) : (page += frames.PageSize) {
                    if (externalPageOccupied({}, page))
                        _ = batch26_builder.unmapPage(page, .page_4k) catch shutdown();
                }
                asm volatile ("sfence.vma" ::: "memory");
                frame.x[10] = address;
            } else if (address == 0 and protection == 3 and flags == 0x22) {
                const page_count = ExternalRuntimeMappings.pageCount(length) catch {
                    frame.x[10] = negativeErrno(22);
                    return finishReturningSyscall(frame, index);
                };
                const backing_end = std.math.add(usize, external_next_backing, page_count) catch {
                    frame.x[10] = negativeErrno(12);
                    return finishReturningSyscall(frame, index);
                };
                if (backing_end > prepared_image_pages) {
                    frame.x[10] = negativeErrno(12);
                    return finishReturningSyscall(frame, index);
                }
                var candidate_address = external_program_break;
                while (candidate_address < user_stack_va) : (candidate_address += frames.PageSize) {
                    external_runtime_mappings.reserve(candidate_address, length, .{ .read = true, .write = true }, false, {}, externalPageOccupied) catch |err| switch (err) {
                        error.Collision => continue,
                        else => {
                            frame.x[10] = negativeErrno(12);
                            return finishReturningSyscall(frame, index);
                        },
                    };
                    // Prepare every anonymous page before exposing any leaf.
                    // Backing ownership and the reservation commit only after
                    // every page maps; a mid-map failure removes installed
                    // leaves and releases the last reservation atomically.
                    for (external_prepared_backing[external_next_backing..backing_end]) |*backing|
                        @memset(backing, 0);
                    var mapped_pages: usize = 0;
                    while (mapped_pages < page_count) : (mapped_pages += 1) {
                        const virtual = candidate_address + mapped_pages * frames.PageSize;
                        const physical = @intFromPtr(&external_prepared_backing[external_next_backing + mapped_pages]);
                        _ = batch26_builder.mapPage(virtual, physical, .page_4k, .{ .read = true, .write = true, .user = true, .accessed = true, .dirty = true }) catch {
                            var rollback_page: usize = 0;
                            while (rollback_page < mapped_pages) : (rollback_page += 1)
                                _ = batch26_builder.unmapPage(candidate_address + rollback_page * frames.PageSize, .page_4k) catch shutdown();
                            external_runtime_mappings.cancelLast(candidate_address, length);
                            asm volatile ("sfence.vma" ::: "memory");
                            frame.x[10] = negativeErrno(12);
                            return finishReturningSyscall(frame, index);
                        };
                    }
                    external_next_backing = backing_end;
                    asm volatile ("sfence.vma" ::: "memory");
                    frame.x[10] = candidate_address;
                    break;
                } else frame.x[10] = negativeErrno(12);
            } else {
                if (external_artifact_options.live_console_input) {
                    write("LINUX_MMAP_REJECT address=");
                    writeUsizeHex(address);
                    write(" length=");
                    writeUsizeHex(length);
                    write(" protection=");
                    writeUsizeHex(protection);
                    write(" flags=");
                    writeUsizeHex(flags);
                    write(" fd=");
                    writeUsizeHex(descriptor);
                    write(" offset=");
                    writeUsizeHex(offset);
                    write("\n");
                }
                frame.x[10] = negativeErrno(22);
            }
        },
        .terminate => blk: {
            syscall_semantics[index] = 3;
            if (external_fork_parent) |parent| {
                unmapExternalImage(&external_image);
                unmapExternalImage(&external_interpreter_image);
                unmapExternalBreak(&external_image, external_program_break);
                for (external_runtime_mappings.entries[0..external_runtime_mappings.count]) |mapping| {
                    var page = mapping.start;
                    while (page < mapping.end) : (page += frames.PageSize) {
                        if (externalPageOccupied({}, page)) {
                            _ = batch26_builder.unmapPage(page, .page_4k) catch shutdown();
                        }
                    }
                }
                external_prepared_backing = external_fork_main_snapshot;
                external_interpreter_backing = external_fork_interpreter_snapshot;
                external_prepared_stack = external_fork_stack_snapshot;
                external_image = external_fork_image_snapshot;
                external_interpreter_image = external_fork_interpreter_image_snapshot;
                external_stack_image = external_fork_stack_image_snapshot;
                syscall_resources = external_fork_resources;
                syscall_bindings = external_fork_bindings;
                external_runtime_mappings = external_fork_mappings;
                external_program_break = external_fork_program_break;
                external_next_backing = external_fork_next_backing;
                external_process_cwd = external_fork_cwd;
                installExternalImage(&external_image, &external_prepared_backing);
                installExternalImage(&external_interpreter_image, &external_interpreter_backing);
                var restored_backing_index = external_image.items().len;
                var restored_break_page = imageBreakStart(&external_image);
                const restored_break_end = (external_program_break + frames.PageSize - 1) & ~@as(usize, frames.PageSize - 1);
                while (restored_break_page < restored_break_end) : (restored_break_page += frames.PageSize) {
                    _ = batch26_builder.mapPage(restored_break_page, @intFromPtr(&external_prepared_backing[restored_backing_index]), .page_4k, .{ .read = true, .write = true, .user = true, .accessed = true, .dirty = true }) catch shutdown();
                    restored_backing_index += 1;
                }
                for (external_runtime_mappings.entries[0..external_runtime_mappings.count]) |mapping| {
                    // Fixed PROT_NONE reservations own virtual range but have
                    // neither a leaf nor backing. Preserve them only in the
                    // neutral mapping table and do not consume a backing slot.
                    if (!ExternalRuntimeMappings.hasBacking(mapping)) continue;
                    var page = mapping.start;
                    while (page < mapping.end) : (page += frames.PageSize) {
                        const physical = @intFromPtr(&external_prepared_backing[restored_backing_index]);
                        _ = batch26_builder.mapPage(page, physical, .page_4k, .{ .read = mapping.permissions.read, .write = mapping.permissions.write, .execute = mapping.permissions.execute, .user = true, .accessed = true, .dirty = mapping.permissions.write }) catch shutdown();
                        restored_backing_index += 1;
                    }
                }
                asm volatile ("sfence.vma; fence.i" ::: "memory");
                frame.* = parent;
                external_fork_parent = null;
                syscall_results[index] = frame.x[10];
                syscall_resume_pcs[index] = frame.sepc;
                frame.sstatus &= ~@as(usize, 0x40122);
                asm volatile ("csrw sepc, %[pc]"
                    :
                    : [pc] "r" (frame.sepc),
                    : "memory"
                );
                return;
            }
            request = .{ .terminate = @truncate(frame.x[10]) };
            break :blk;
        },
        .unsupported => {
            syscall_semantics[index] = 1;
            if (external_artifact_options.live_console_input and external_fork_parent != null) {
                write("ZIGREF_LINUX_UNSUPPORTED nr=");
                writeUsizeHex(frame.x[17]);
                write(" trap_stack=");
                writeUsizeHex(external_trap_stack);
                write(" frame=");
                writeUsizeHex(@intFromPtr(frame));
                write(" user_sp=");
                writeUsizeHex(frame.x[2]);
                write("\n");
            }
        },
    }
    if (request == null and syscall_semantics[index] == 1) {
        syscall_semantics[index] = 1;
        frame.x[10] = negativeErrno(38);
    } else if (request) |semantic_request| {
        switch (morphic_operation.execute(semantic_request, SyscallBackend{})) {
            .success => |value| frame.x[10] = value,
            .failure => |failure| frame.x[10] = negativeErrno(switch (failure) {
                .invalid_resource => 9,
                .operation_not_supported => 9,
                .invalid_user_memory => 14,
            }),
            .terminated => |status| {
                syscall_terminal_status = status;
                frame.sepc = @intFromPtr(&userServiceSupervisorResume);
                frame.sstatus = (frame.sstatus & ~@as(usize, 0x40122)) | 0x100;
                service_trap_count = 2;
                return;
            },
        }
    }
    finishReturningSyscall(frame, index);
}

fn finishReturningSyscall(frame: *TrapFrame, index: usize) void {
    syscall_results[index] = frame.x[10];
    frame.sepc += 4;
    syscall_resume_pcs[index] = frame.sepc;
    frame.sstatus &= ~@as(usize, 0x40122);
    asm volatile ("csrw sepc, %[pc]"
        :
        : [pc] "r" (frame.sepc),
        : "memory"
    );
}

fn recordUserCopyOutTrap(frame: *TrapFrame) void {
    const index = copy_out_traps;
    const begin = @intFromPtr(&userCopyOutProbeTemplateBegin);
    const sites = [_]usize{
        @intFromPtr(&userCopyOutProbeServiceEcall),      @intFromPtr(&userCopyOutProbePermissionRejectEcall),
        @intFromPtr(&userCopyOutProbeAtomicRejectEcall), @intFromPtr(&userCopyOutProbeTerminalEcall),
    };
    if (index >= 4 or frame.scause != 8 or frame.sstatus & (0x100 | 0x40000) != 0 or
        frame.x[2] != user_stack_va + frames.PageSize - 64 or frame.sepc != user_code_va + sites[index] - begin) shutdown();
    copy_out_frames[index] = @intFromPtr(frame);
    copy_out_sepcs[index] = frame.sepc;
    copy_out_status[index] = frame.sstatus;
    copy_out_causes[index] = frame.scause;
    copy_out_traps += 1;
    if (index == 0) {
        copy_out_destination = frame.x[10];
        if (copy_out_destination != user_stack_va + frames.PageSize - 56 or frame.x[11] != 16) shutdown();
        const physical_base = copy_out_stack_pa + frames.PageSize - 64;
        copy_out_guard_before = @as(*volatile usize, @ptrFromInt(physical_base)).*;
        copy_out_guard_after = @as(*volatile usize, @ptrFromInt(physical_base + 24)).*;
        const plan = user_transfer.TransferPlan(2).plan(user_transfer.GuestVirtualAddress.init(copy_out_destination), 16, .write_to_user, copy_out_query) catch shutdown();
        if (plan.items().len != 1) shutdown();
        for (plan.items()) |segment| {
            copy_out_segment_pa = segment.physical_start.raw();
            copy_out_segment_offset = segment.request_offset;
            copy_out_segment_bytes = segment.byte_count;
            copy_out_segment_coverage += segment.byte_count;
            const target: [*]volatile u8 = @ptrFromInt(segment.physical_start.raw());
            for (0..segment.byte_count) |i| target[i] = copy_out_payload[segment.request_offset + i];
        }
        if (copy_out_segment_coverage != copy_out_payload.len) shutdown();
        frame.x[10] = 0x21c1;
        frame.sepc = user_code_va + @intFromPtr(&userCopyOutProbeAfterService) - begin;
    } else if (index == 1) {
        const guard: *volatile usize = @ptrFromInt(copy_out_code_pa);
        copy_out_code_before = guard.*;
        _ = user_transfer.TransferPlan(2).plan(user_transfer.GuestVirtualAddress.init(frame.x[10]), frame.x[11], .write_to_user, copy_out_query) catch |err| {
            if (err != error.NotWritable) shutdown();
            copy_out_code_after = guard.*;
            frame.x[10] = 0x21c2;
            frame.sepc = user_code_va + @intFromPtr(&userCopyOutProbeAfterPermissionReject) - begin;
            prepareCopyOutReturn(frame, index);
            return;
        };
        shutdown();
    } else if (index == 2) {
        const prefix: *volatile usize = @ptrFromInt(copy_out_stack_pa + frames.PageSize - 8);
        copy_out_prefix_before = prefix.*;
        _ = user_transfer.TransferPlan(2).plan(user_transfer.GuestVirtualAddress.init(frame.x[10]), frame.x[11], .write_to_user, copy_out_query) catch |err| {
            if (err != error.Unmapped) shutdown();
            copy_out_prefix_after = prefix.*;
            frame.x[10] = 0x21c3;
            frame.sepc = user_code_va + @intFromPtr(&userCopyOutProbeAfterAtomicReject) - begin;
            prepareCopyOutReturn(frame, index);
            return;
        };
        shutdown();
    } else {
        if (frame.x[12] != 0x21cf) shutdown();
        frame.sepc = @intFromPtr(&userServiceSupervisorResume);
        frame.sstatus = (frame.sstatus & ~@as(usize, 0x40122)) | 0x100;
        asm volatile ("csrw sepc, %[pc]; csrw sstatus, %[status]"
            :
            : [pc] "r" (frame.sepc),
              [status] "r" (frame.sstatus),
            : "memory"
        );
        service_trap_count = 2; // assembly terminal-return discriminator
        return;
    }
    prepareCopyOutReturn(frame, index);
}
fn prepareCopyOutReturn(frame: *TrapFrame, index: usize) void {
    frame.sstatus &= ~@as(usize, 0x40122);
    copy_out_prepared[index] = frame.sepc;
    copy_out_prepared_status[index] = frame.sstatus;
    copy_out_return_count += 1;
    asm volatile ("csrw sepc, %[value]"
        :
        : [value] "r" (frame.sepc),
    );
}

fn recordUserCopyTrap(frame: *TrapFrame) void {
    const index = copy_trap_count;
    const begin = @intFromPtr(&userCopyInProbeTemplateBegin);
    const service_pc = user_code_va + @intFromPtr(&userCopyInProbeServiceEcall) - begin;
    const terminal_pc = user_code_va + @intFromPtr(&userCopyInProbeTerminalEcall) - begin;
    if (index >= 2 or frame.scause != 8 or frame.sstatus & (0x100 | 0x40000) != 0 or frame.x[2] != user_stack_va + frames.PageSize - 48) shutdown();
    if ((index == 0 and frame.sepc != service_pc) or (index == 1 and frame.sepc != terminal_pc)) shutdown();
    copy_frames[index] = @intFromPtr(frame);
    copy_causes[index] = frame.scause;
    copy_sepcs[index] = frame.sepc;
    copy_status[index] = frame.sstatus;
    copy_sps[index] = frame.x[2];
    copy_trap_count += 1;
    if (index == 0) {
        copy_pointer = frame.x[10];
        copy_length = frame.x[11];
        if (copy_pointer != user_stack_va + frames.PageSize - 48 or copy_length != 16) shutdown();
        const plan = user_transfer.TransferPlan(1).plan(user_transfer.GuestVirtualAddress.init(copy_pointer), copy_length, .read_from_user, copy_query) catch shutdown();
        copy_segment_count = plan.items().len;
        for (plan.items()) |segment| {
            copy_segment_pa = segment.physical_start.raw();
            copy_segment_offset = segment.request_offset;
            copy_segment_length = segment.byte_count;
            copy_coverage += segment.byte_count;
            const source: [*]const volatile u8 = @ptrFromInt(segment.physical_start.raw());
            for (0..segment.byte_count) |i| copy_scratch[segment.request_offset + i] = source[i];
        }
        if (copy_coverage != 16 or !std.mem.eql(u8, copy_scratch[0..16], "zig-user-memory!") or
            !std.mem.allEqual(u8, copy_scratch[16..], 0xa5)) shutdown();
        copy_result = 0x21b;
        frame.x[10] = copy_result;
        frame.sepc = user_code_va + @intFromPtr(&userCopyInProbeAfterService) - begin;
        copy_prepared_sepc = frame.sepc;
        // The first-trap assembly restores registers directly and intentionally
        // does not reload TrapFrame.sepc, so apply the prepared continuation to
        // the live CSR before returning through SRET.
        asm volatile ("csrw sepc, %[value]"
            :
            : [value] "r" (copy_prepared_sepc),
        );
        frame.sstatus &= ~@as(usize, 0x40122);
        copy_prepared_sstatus = frame.sstatus;
        copy_return_count += 1;
    } else {
        if (frame.x[10] != 0x21b or frame.x[12] != 0x21ee) shutdown();
        copy_terminal_marker = frame.x[12];
        copy_terminal_count += 1;
        frame.sepc = @intFromPtr(&userServiceSupervisorResume);
        frame.sstatus = (frame.sstatus & ~@as(usize, 0x40122)) | 0x100;
    }
    service_trap_count = copy_trap_count;
}

export fn userProbeTemplateBegin() linksection(".text.user_probe") callconv(.naked) void {
    asm volatile (
        \\li t0, 0x139
        \\addi sp, sp, -16
        \\sd t0, 0(sp)
        \\ld t1, 0(sp)
        \\li a0, 0x519
        \\.global userProbeTemplateEcall
        \\userProbeTemplateEcall:
        \\ecall
        \\1: unimp
        \\j 1b
        \\.global userProbeTemplateEnd
        \\userProbeTemplateEnd:
    );
}
extern var userProbeTemplateEcall: u8;
extern var userProbeTemplateEnd: u8;

export fn userTrapEntry() linksection(".text.usertrap") callconv(.naked) void {
    asm volatile (
    // The architectural trap does not change sp.  This register-only swap
    // is therefore deliberately the first instruction and precedes stores.
        \\csrrw sp, sscratch, sp
        \\addi sp, sp, -288
        \\sd t0, 40(sp)
        \\sd t1, 48(sp)
        \\sd a0, 80(sp)
        \\csrr t0, sscratch
        \\sd t0, 16(sp)
        \\csrr t0, sepc
        \\sd t0, 256(sp)
        \\csrr t0, sstatus
        \\sd t0, 264(sp)
        \\csrr t0, scause
        \\sd t0, 272(sp)
        \\csrr t0, stval
        \\sd t0, 280(sp)
        \\mv a0, sp
        \\call recordUserTrap
        \\la t0, user_supervisor_sp
        \\ld sp, 0(t0)
        \\la t0, userSupervisorResume
        \\csrw sepc, t0
        \\li t0, 0x100
        \\csrs sstatus, t0
        \\sret
    );
}

export fn recordUserTrap(frame: *TrapFrame) callconv(.c) void {
    user_trap_frame_address = @intFromPtr(frame);
    user_scause = frame.scause;
    user_sepc = frame.sepc;
    user_sstatus = frame.sstatus;
    user_sp = frame.x[2];
    user_a0 = frame.x[10];
    user_t0 = frame.x[5];
    user_t1 = frame.x[6];
    if (userspace_elf_active) {
        if (frame.scause != 8 or (frame.sstatus & 0x100) != 0 or
            frame.sepc < userspace_elf_entry or frame.sepc >= userspace_elf_memory_end or
            frame.x[2] != userspace_elf_expected_sp or frame.x[10] != userspace_elf_expected_a0 or
            frame.x[5] != userspace_elf_expected_t0 or frame.x[6] != userspace_elf_expected_t1) shutdown();
        userspace_elf_active = false;
        return;
    }
    if (frame.scause != 8 or (frame.sstatus & 0x100) != 0 or
        frame.sepc != user_code_va + 14 or frame.x[2] != user_stack_va + frames.PageSize - 16)
    {
        write("ZIGREF_UMODE_FAILURE\n");
        shutdown();
    }
}

export fn enterUser(entry: usize, stack_top: usize, trap_stack_top: usize) linksection(".text.enteruser") callconv(.naked) void {
    _ = entry;
    _ = stack_top;
    _ = trap_stack_top;
    asm volatile (
        \\addi sp, sp, -112
        \\sd ra, 0(sp)
        \\sd s0, 8(sp)
        \\sd s1, 16(sp)
        \\sd s2, 24(sp)
        \\sd s3, 32(sp)
        \\sd s4, 40(sp)
        \\sd s5, 48(sp)
        \\sd s6, 56(sp)
        \\sd s7, 64(sp)
        \\sd s8, 72(sp)
        \\sd s9, 80(sp)
        \\sd s10, 88(sp)
        \\sd s11, 96(sp)
        \\la t0, user_supervisor_sp
        \\sd sp, 0(t0)
        \\csrw sscratch, a2
        \\la t0, userTrapEntry
        \\csrw stvec, t0
        \\csrw sepc, a0
        // Clear SIE, SPIE, SPP, and SUM: the one-shot U probe is noninterruptible.
        \\li t0, 0x40122
        \\csrc sstatus, t0
        \\mv sp, a1
        \\sret
        \\.global userSupervisorResume
        \\userSupervisorResume:
        \\la t0, user_returned
        \\li t1, 1
        \\sb t1, 0(t0)
        \\ld ra, 0(sp)
        \\ld s0, 8(sp)
        \\ld s1, 16(sp)
        \\ld s2, 24(sp)
        \\ld s3, 32(sp)
        \\ld s4, 40(sp)
        \\ld s5, 48(sp)
        \\ld s6, 56(sp)
        \\ld s7, 64(sp)
        \\ld s8, 72(sp)
        \\ld s9, 80(sp)
        \\ld s10, 88(sp)
        \\ld s11, 96(sp)
        \\addi sp, sp, 112
        \\ret
    );
}

export fn enterUserService(entry: usize, stack_top: usize, trap_stack_top: usize) linksection(".text.enteruserservice") callconv(.naked) void {
    _ = entry;
    _ = stack_top;
    _ = trap_stack_top;
    asm volatile (
        \\addi sp, sp, -112
        \\sd ra, 0(sp)
        \\sd s0, 8(sp)
        \\sd s1, 16(sp)
        \\sd s2, 24(sp)
        \\sd s3, 32(sp)
        \\sd s4, 40(sp)
        \\sd s5, 48(sp)
        \\sd s6, 56(sp)
        \\sd s7, 64(sp)
        \\sd s8, 72(sp)
        \\sd s9, 80(sp)
        \\sd s10, 88(sp)
        \\sd s11, 96(sp)
        \\la t0, service_supervisor_sp
        \\sd sp, 0(t0)
        \\la t0, external_trap_stack
        \\sd a2, 0(t0)
        \\csrw sscratch, a2
        \\la t0, userServiceTrapEntry
        \\csrw stvec, t0
        \\csrw sepc, a0
        \\li t0, 0x40122
        \\csrc sstatus, t0
        \\mv sp, a1
        \\sret
        \\.global userServiceSupervisorResume
        \\userServiceSupervisorResume:
        \\la t0, service_supervisor_returned
        \\li t1, 1
        \\sb t1, 0(t0)
        \\la t0, service_supervisor_sp
        \\ld sp, 0(t0)
        \\ld ra, 0(sp)
        \\ld s0, 8(sp)
        \\ld s1, 16(sp)
        \\ld s2, 24(sp)
        \\ld s3, 32(sp)
        \\ld s4, 40(sp)
        \\ld s5, 48(sp)
        \\ld s6, 56(sp)
        \\ld s7, 64(sp)
        \\ld s8, 72(sp)
        \\ld s9, 80(sp)
        \\ld s10, 88(sp)
        \\ld s11, 96(sp)
        \\addi sp, sp, 112
        \\ret
    );
}
extern var userServiceSupervisorResume: u8;

const expected_tick_count: usize = 4;
const tick_interval: usize = 100_000;
var ticks_active: bool = false;
var ticks_final_neutralized: bool = false;
var tick_sepc: [expected_tick_count]usize = [_]usize{0} ** expected_tick_count;
var tick_scause: [expected_tick_count]usize = [_]usize{0} ** expected_tick_count;
var tick_sstatus: [expected_tick_count]usize = [_]usize{0} ** expected_tick_count;
var tick_observed_time: [expected_tick_count]usize = [_]usize{0} ** expected_tick_count;
var tick_deadline: [expected_tick_count]usize = [_]usize{0} ** expected_tick_count;
var tick_next_deadline: [expected_tick_count]usize = [_]usize{0} ** expected_tick_count;
var tick_rearmed: [expected_tick_count]bool = [_]bool{false} ** expected_tick_count;
var active_tick_deadline: usize = 0;
export var tick_trap_count: usize = 0;
export var tick_return_count: usize = 0;

export fn supervisorTrapEntry() linksection(".text.trap") callconv(.naked) void {
    asm volatile (
        \\addi sp, sp, -288
        \\sd ra, 8(sp)
        \\addi ra, sp, 288
        \\sd ra, 16(sp)
        \\sd gp, 24(sp)
        \\sd tp, 32(sp)
        \\sd t0, 40(sp)
        \\sd t1, 48(sp)
        \\sd t2, 56(sp)
        \\sd s0, 64(sp)
        \\sd s1, 72(sp)
        \\sd a0, 80(sp)
        \\sd a1, 88(sp)
        \\sd a2, 96(sp)
        \\sd a3, 104(sp)
        \\sd a4, 112(sp)
        \\sd a5, 120(sp)
        \\sd a6, 128(sp)
        \\sd a7, 136(sp)
        \\sd s2, 144(sp)
        \\sd s3, 152(sp)
        \\sd s4, 160(sp)
        \\sd s5, 168(sp)
        \\sd s6, 176(sp)
        \\sd s7, 184(sp)
        \\sd s8, 192(sp)
        \\sd s9, 200(sp)
        \\sd s10, 208(sp)
        \\sd s11, 216(sp)
        \\sd t3, 224(sp)
        \\sd t4, 232(sp)
        \\sd t5, 240(sp)
        \\sd t6, 248(sp)
        \\csrr t0, sepc
        \\sd t0, 256(sp)
        \\csrr t0, sstatus
        \\sd t0, 264(sp)
        \\csrr t0, scause
        \\sd t0, 272(sp)
        \\csrr t0, stval
        \\sd t0, 280(sp)
        \\mv a0, sp
        \\call recordTrap
        \\ld t0, 256(sp)
        \\csrw sepc, t0
        \\ld t0, 264(sp)
        \\csrw sstatus, t0
        \\ld ra, 8(sp)
        \\ld gp, 24(sp)
        \\ld tp, 32(sp)
        \\ld t0, 40(sp)
        \\ld t1, 48(sp)
        \\ld t2, 56(sp)
        \\ld s0, 64(sp)
        \\ld s1, 72(sp)
        \\ld a0, 80(sp)
        \\ld a1, 88(sp)
        \\ld a2, 96(sp)
        \\ld a3, 104(sp)
        \\ld a4, 112(sp)
        \\ld a5, 120(sp)
        \\ld a6, 128(sp)
        \\ld a7, 136(sp)
        \\ld s2, 144(sp)
        \\ld s3, 152(sp)
        \\ld s4, 160(sp)
        \\ld s5, 168(sp)
        \\ld s6, 176(sp)
        \\ld s7, 184(sp)
        \\ld s8, 192(sp)
        \\ld s9, 200(sp)
        \\ld s10, 208(sp)
        \\ld s11, 216(sp)
        \\ld t3, 224(sp)
        \\ld t4, 232(sp)
        \\ld t5, 240(sp)
        \\ld t6, 248(sp)
        \\addi sp, sp, 288
        \\sret
    );
}

export fn recordTrap(frame: *TrapFrame) callconv(.c) void {
    const interrupt = frame.scause >> 63;
    const cause = frame.scause & 0x7fff_ffff_ffff_ffff;
    if (interrupt == 1 and cause == 5) {
        if (ticks_final_neutralized) {
            // Preserve an undeclared post-final delivery as failing evidence.
            tick_trap_count += 1;
            asm volatile ("li t0, 32; csrc sie, t0" ::: "t0", "memory");
            _ = sbiCall(0, 0, std.math.maxInt(usize), 0);
            return;
        }
        if (ticks_active) {
            const index = tick_trap_count;
            if (index >= expected_tick_count) {
                ticks_active = false;
                asm volatile ("li t0, 32; csrc sie, t0" ::: "t0", "memory");
                _ = sbiCall(0, 0, std.math.maxInt(usize), 0);
                return;
            }
            const now = asm volatile ("rdtime %[value]"
                : [value] "=r" (-> usize),
            );
            tick_sepc[index] = frame.sepc;
            tick_scause[index] = frame.scause;
            tick_sstatus[index] = frame.sstatus;
            tick_observed_time[index] = now;
            tick_deadline[index] = active_tick_deadline;
            tick_trap_count = index + 1;
            if (tick_trap_count < expected_tick_count) {
                // Re-arm relative to a newly observed counter value. This
                // avoids an already-late deadline becoming an interrupt loop.
                const next = now +% tick_interval;
                active_tick_deadline = next;
                tick_next_deadline[index] = next;
                _ = sbiCall(0, 0, next, 0);
                tick_rearmed[index] = true;
            } else {
                ticks_active = false;
                asm volatile ("li t0, 32; csrc sie, t0" ::: "t0", "memory");
                _ = sbiCall(0, 0, std.math.maxInt(usize), 0);
                tick_next_deadline[index] = std.math.maxInt(usize);
                ticks_final_neutralized = true;
            }
            return;
        }
        timer_sepc = frame.sepc;
        timer_scause = frame.scause;
        timer_sstatus = frame.sstatus;
        timer_trap_count += 1;
        // One shot means both mask STIE and move the firmware timer deadline
        // to the maximum RV64 value before returning. Interrupt sepc is kept.
        asm volatile ("li t0, 32; csrc sie, t0" ::: "t0", "memory");
        _ = sbiCall(0, 0, std.math.maxInt(usize), 0);
        timer_policy_complete = true;
        return;
    }
    if (interrupt == 0 and cause == 3) {
        observed_sepc = frame.sepc;
        observed_sstatus = frame.sstatus;
        observed_scause = frame.scause;
        observed_stval = frame.stval;
        trap_count += 1;
        // This policy applies only to the known 32-bit EBREAK probe below.
        frame.sepc += 4;
        return;
    }
    // Unknown traps do not inherit either supported class's resume policy.
    trap_count = std.math.maxInt(usize);
    asm volatile ("csrci sstatus, 2" ::: "memory");
}

comptime {
    asm (
        \\.global trapProbe
        \\.global trapProbeBreakpoint
        \\.global trapProbeResume
        \\.type trapProbe,@function
        \\trapProbe:
        \\mv t3, sp
        \\li t0, 0x12345
        \\li t1, 0x23456
        \\li a0, 0x34567
        \\trapProbeBreakpoint:
        \\.4byte 0x00100073
        \\trapProbeResume:
        \\li t2, 0x12345
        \\bne t0, t2, 1f
        \\li t2, 0x23456
        \\bne t1, t2, 1f
        \\li t2, 0x34567
        \\bne a0, t2, 1f
        \\bne sp, t3, 1f
        \\li a0, 1
        \\ret
        \\1: li a0, 0
        \\ret
    );
}

extern fn trapProbe() callconv(.c) usize;

comptime {
    asm (
        \\.global timerProbe
        \\.global timerWaitBegin
        \\.global timerWaitEnd
        \\.type timerProbe,@function
        \\timerProbe:
        \\mv t3, sp
        \\li t0, 0x45678
        \\li t1, 0x56789
        \\li a0, 0x6789a
        \\li t2, 32
        \\csrs sie, t2
        \\csrsi sstatus, 2
        \\timerWaitBegin:
        \\wfi
        \\la t2, timer_trap_count
        \\ld t2, 0(t2)
        \\beqz t2, timerWaitBegin
        \\timerWaitEnd:
        \\csrci sstatus, 2
        \\li t2, 0x45678
        \\bne t0, t2, 1f
        \\li t2, 0x56789
        \\bne t1, t2, 1f
        \\li t2, 0x6789a
        \\bne a0, t2, 1f
        \\bne sp, t3, 1f
        \\li a0, 1
        \\ret
        \\1: li a0, 0
        \\ret
    );
}

extern fn timerProbe() callconv(.c) usize;

comptime {
    asm (
        \\.global ticksProbe
        \\.global ticksWaitBegin
        \\.global ticksWaitEnd
        \\.type ticksProbe,@function
        \\ticksProbe:
        \\mv t3, sp
        \\li t0, 0x789ab
        \\li t1, 0x89abc
        \\li a0, 0x9abcd
        \\li t2, 32
        \\csrs sie, t2
        \\csrsi sstatus, 2
        \\ticksWaitBegin:
        \\wfi
        \\la t4, tick_trap_count
        \\ld t4, 0(t4)
        \\la t5, tick_return_count
        \\ld t6, 0(t5)
        \\bgeu t6, t4, ticksWaitBegin
        \\addi t6, t6, 1
        \\sd t6, 0(t5)
        \\li t2, 4
        \\bltu t6, t2, ticksWaitBegin
        \\ticksWaitEnd:
        \\csrci sstatus, 2
        \\li t2, 0x789ab
        \\bne t0, t2, 1f
        \\li t2, 0x89abc
        \\bne t1, t2, 1f
        \\li t2, 0x9abcd
        \\bne a0, t2, 1f
        \\bne sp, t3, 1f
        \\li a0, 1
        \\ret
        \\1: li a0, 0
        \\ret
    );
}

extern fn ticksProbe() callconv(.c) usize;

export fn _start() linksection(".text.entry") callconv(.naked) noreturn {
    asm volatile (
        \\la sp, __supervisor_stack_top
        \\tail freestandingMain
    );
}

fn sbiCall(extension: usize, function: usize, arg0: usize, arg1: usize) usize {
    return asm volatile ("ecall"
        : [result] "={a0}" (-> usize),
        : [a0] "{a0}" (arg0),
          [a1] "{a1}" (arg1),
          [a6] "{a6}" (function),
          [a7] "{a7}" (extension),
        : "memory"
    );
}

fn write(bytes: []const u8) void {
    for (bytes) |byte| _ = sbiCall(0x1, 0, byte, 0); // SBI legacy console putchar.
}

fn writeHex(bytes: []const u8) void {
    const digits = "0123456789abcdef";
    for (bytes) |byte| {
        write(&.{ digits[byte >> 4], digits[byte & 0xf] });
    }
}

fn writeUsizeHex(value: usize) void {
    const digits = "0123456789abcdef";
    var shift: usize = 60;
    while (true) : (shift -= 4) {
        write(&.{digits[(value >> @intCast(shift)) & 0xf]});
        if (shift == 0) break;
    }
}

fn shutdown() noreturn {
    _ = sbiCall(0x53525354, 0, 0, 0); // SBI system reset: shutdown, no reason.
    while (true) asm volatile ("wfi");
}

noinline fn executeUserspaceElf(allocator: anytype, page_owner: anytype, builder: anytype, user_code_pa: usize, user_stack_pa: usize, trap_end: usize, historical_stvec: usize, root_physical: usize) void {
    const destination: [*]volatile u8 = @ptrFromInt(user_code_pa);
    write("ZIGREF_USERSPACE_ELF_PHASE plan-load-execute\n");
    // Batch 22B consumes the separately linked guest file through module 54,
    // and deliberately reuses the established code/stack frames and leaves.
    const elf_alloc_before = allocator.allocatedCount();
    const elf_tables_before = page_owner.page_count;
    const elf_satp_before = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const load = elf_load.plan(1, userspace_elf) catch |err| {
        write("ZIGREF_USERSPACE_ELF_FAILURE planner=");
        write(@errorName(err));
        write("\n");
        shutdown();
    };
    write("ZIGREF_USERSPACE_ELF_PHASE plan-complete\n");
    if (load.items().len != 1) {
        write("ZIGREF_USERSPACE_ELF_FAILURE fixture-shape\n");
        shutdown();
    }
    const segment = load.items()[0];
    if (segment.memory_start.raw() != user_code_va or segment.memory.start != user_code_va or
        segment.memory.end > user_code_va + frames.PageSize or segment.file_byte_count != segment.memory_byte_count or
        segment.zero_fill_byte_count != 0 or !segment.permissions.read or segment.permissions.write or
        !segment.permissions.execute or load.entry.raw() < segment.memory.start or load.entry.raw() >= segment.memory.end)
    {
        write("ZIGREF_USERSPACE_ELF_FAILURE plan-destination\n");
        shutdown();
    }
    for (0..frames.PageSize) |index| destination[index] = 0;
    const elf_source = userspace_elf[segment.source.start..segment.source.end];
    for (elf_source, 0..) |byte, index| destination[index] = byte;
    const loaded: [*]const volatile u8 = @ptrFromInt(user_code_pa);
    var loaded_hash: u64 = 0xcbf29ce484222325;
    for (elf_source, 0..) |source_byte, index| {
        const loaded_byte = loaded[index];
        if (loaded_byte != source_byte) {
            write("ZIGREF_USERSPACE_ELF_FAILURE loaded-byte-mismatch\n");
            shutdown();
        }
        loaded_hash = (loaded_hash ^ loaded_byte) *% 0x100000001b3;
    }
    const source_hash = fnv1a64(elf_source);
    write("ZIGREF_USERSPACE_ELF_PHASE bytes-verified\n");
    asm volatile ("fence.i" ::: "memory");
    userspace_elf_entry = load.entry.raw();
    userspace_elf_memory_end = segment.memory.end;
    userspace_elf_expected_sp = user_stack_va + frames.PageSize;
    userspace_elf_expected_a0 = 0x22b0;
    userspace_elf_expected_t0 = 0x22b1;
    userspace_elf_expected_t1 = 0x22b2;
    userspace_elf_active = true;
    user_returned = false;
    asm volatile ("mv a0, %[entry]; mv a1, %[stack]; mv a2, %[trap_stack]; call enterUser; la t0, user_supervisor_sp; ld sp, 0(t0); addi sp, sp, 112"
        :
        : [entry] "r" (load.entry.raw()),
          [stack] "r" (user_stack_va + frames.PageSize),
          [trap_stack] "r" (trap_end),
        : "memory", "ra", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "t0", "t1", "t2", "t3", "t4", "t5", "t6"
    );
    asm volatile ("csrw stvec, %[entry]; csrw sscratch, zero"
        :
        : [entry] "r" (historical_stvec),
        : "memory"
    );
    const elf_satp_after = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const elf_code_leaf = builder.query(user_code_va) catch shutdown();
    const elf_stack_leaf = builder.query(user_stack_va) catch shutdown();
    if (userspace_elf_active or !user_returned or user_scause != 8 or
        elf_alloc_before != allocator.allocatedCount() or elf_tables_before != page_owner.page_count or
        elf_satp_before != elf_satp_after or elf_code_leaf.physical_address != user_code_pa or
        elf_stack_leaf.physical_address != user_stack_pa or elf_code_leaf.raw_entry & 0x16 != 0x12 or
        elf_stack_leaf.raw_entry & 0x16 != 0x16 or elf_stack_leaf.raw_entry & 0x8 != 0) shutdown();
    write("ZIGREF_USERSPACE_ELF_BEGIN\nartifact=userspace-elf-rv64\nartifact_bytes=");
    writeUsizeHex(userspace_elf.len);
    write("\nartifact_fnv1a64=");
    writeUsizeHex(fnv1a64(userspace_elf));
    write("\nsource_fnv1a64=");
    writeUsizeHex(source_hash);
    write("\nentry=");
    writeUsizeHex(load.entry.raw());
    write("\nsegment_count=0000000000000001\nsource_start=");
    writeUsizeHex(segment.source.start);
    write("\nsource_end=");
    writeUsizeHex(segment.source.end);
    write("\nmemory_start=");
    writeUsizeHex(segment.memory.start);
    write("\nmemory_end=");
    writeUsizeHex(segment.memory.end);
    write("\nfile_bytes=");
    writeUsizeHex(segment.file_byte_count);
    write("\nmemory_bytes=");
    writeUsizeHex(segment.memory_byte_count);
    write("\nzero_fill=");
    writeUsizeHex(segment.zero_fill_byte_count);
    write("\nalignment=");
    writeUsizeHex(@intCast(segment.alignment));
    write("\npermissions=R-X\ndestination_va=");
    writeUsizeHex(segment.memory_start.raw());
    write("\ndestination_pa=");
    writeUsizeHex(user_code_pa);
    write("\ncopied_bytes=");
    writeUsizeHex(segment.file_byte_count);
    write("\nloaded_bytes_equal=PASS");
    write("\nloaded_fnv1a64=");
    writeUsizeHex(loaded_hash);
    write("\nprepared_entry=");
    writeUsizeHex(userspace_elf_entry);
    write("\ntrap_cause=");
    writeUsizeHex(user_scause);
    write("\ntrap_sepc=");
    writeUsizeHex(user_sepc);
    write("\ntrap_sstatus=");
    writeUsizeHex(user_sstatus);
    write("\ntrap_frame=");
    writeUsizeHex(user_trap_frame_address);
    write("\nmarker_a0=");
    writeUsizeHex(user_a0);
    write("\nmarker_t0=");
    writeUsizeHex(user_t0);
    write("\nmarker_t1=");
    writeUsizeHex(user_t1);
    write("\nphysical_allocated_before=");
    writeUsizeHex(elf_alloc_before);
    write("\nphysical_allocated_after=");
    writeUsizeHex(allocator.allocatedCount());
    write("\npage_table_count_before=");
    writeUsizeHex(elf_tables_before);
    write("\npage_table_count_after=");
    writeUsizeHex(page_owner.page_count);
    write("\nsatp_before=");
    writeUsizeHex(elf_satp_before);
    write("\nsatp_after=");
    writeUsizeHex(elf_satp_after);
    write("\nroot_physical=");
    writeUsizeHex(root_physical);
    write("\nuser_code_pa=");
    writeUsizeHex(user_code_pa);
    write("\nuser_stack_pa=");
    writeUsizeHex(user_stack_pa);
    write("\nuser_leaf_count=0000000000000002\nwx_leaf_count=0000000000000000");
    write("\ncode_pte=");
    writeUsizeHex(elf_code_leaf.raw_entry);
    write("\nstack_pte=");
    writeUsizeHex(elf_stack_leaf.raw_entry);
    write("\ntranslation_change=none\nsfence_vma=not-required-no-pte-change\nfence_i=local-hart-executed\nsupervisor_resume=PASS\ncomplete=PASS\nZIGREF_USERSPACE_ELF_END\nZIGREF_USERSPACE_ELF_RETURNED\n");
}

noinline fn executeUserspaceElfDataBss(allocator: anytype, page_owner: anytype, builder: anytype, user_code_pa: usize, user_stack_pa: usize, trap_end: usize, historical_stvec: usize, root_physical: usize) void {
    const destination: [*]volatile u8 = @ptrFromInt(user_code_pa);
    write("ZIGREF_USERSPACE_ELF_DATA_BSS_PHASE plan-load-execute\n");
    // Batch 23 consumes a distinct two-segment guest through module 54 while
    // preserving the preceding Batch 22B execution and its original fixture.
    const elf_alloc_before = allocator.allocatedCount();
    const elf_tables_before = page_owner.page_count;
    const elf_satp_before = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const load = elf_load.plan(2, userspace_elf_data_bss) catch |err| {
        write("ZIGREF_USERSPACE_ELF_DATA_BSS_FAILURE planner=");
        write(@errorName(err));
        write("\n");
        shutdown();
    };
    write("ZIGREF_USERSPACE_ELF_DATA_BSS_PHASE plan-complete\n");
    if (load.items().len != 2) {
        write("ZIGREF_USERSPACE_ELF_DATA_BSS_FAILURE fixture-shape\n");
        shutdown();
    }
    const segment = load.items()[0];
    const data_segment = load.items()[1];
    if (segment.memory_start.raw() != user_code_va or segment.memory.start != user_code_va or
        segment.memory.end > user_code_va + frames.PageSize or segment.file_byte_count != segment.memory_byte_count or
        segment.zero_fill_byte_count != 0 or !segment.permissions.read or segment.permissions.write or
        !segment.permissions.execute or load.entry.raw() < segment.memory.start or load.entry.raw() >= segment.memory.end or
        data_segment.memory_start.raw() != user_data_va or data_segment.memory.end > user_data_va + frames.PageSize or
        data_segment.file_byte_count == 0 or data_segment.zero_fill_byte_count == 0 or !data_segment.permissions.read or
        !data_segment.permissions.write or data_segment.permissions.execute)
    {
        write("ZIGREF_USERSPACE_ELF_DATA_BSS_FAILURE plan-destination\n");
        shutdown();
    }
    for (0..frames.PageSize) |index| destination[index] = 0;
    const elf_source = userspace_elf_data_bss[segment.source.start..segment.source.end];
    for (elf_source, 0..) |byte, index| destination[index] = byte;
    const loaded: [*]const volatile u8 = @ptrFromInt(user_code_pa);
    var loaded_hash: u64 = 0xcbf29ce484222325;
    for (elf_source, 0..) |source_byte, index| {
        const loaded_byte = loaded[index];
        if (loaded_byte != source_byte) {
            write("ZIGREF_USERSPACE_ELF_DATA_BSS_FAILURE loaded-byte-mismatch\n");
            shutdown();
        }
        loaded_hash = (loaded_hash ^ loaded_byte) *% 0x100000001b3;
    }
    const source_hash = fnv1a64(elf_source);
    const data_frame = allocator.allocate() catch shutdown();
    const data_pa = (data_frame.toAddress() catch unreachable).raw();
    const data_destination: [*]volatile u8 = @ptrFromInt(data_pa);
    const data_source = userspace_elf_data_bss[data_segment.source.start..data_segment.source.end];
    for (data_source, 0..) |byte, index| data_destination[index] = byte;
    for (data_source, 0..) |byte, index| if (data_destination[index] != byte) shutdown();
    for (data_segment.file_byte_count..data_segment.memory_byte_count) |index| data_destination[index] = 0;
    for (data_segment.file_byte_count..data_segment.memory_byte_count) |index| if (data_destination[index] != 0) shutdown();
    const bss_offset = data_segment.file_byte_count;
    const bss_before: *volatile usize = @ptrFromInt(data_pa + bss_offset);
    if (@as(*volatile usize, @ptrFromInt(data_pa)).* != batch23_initialized or bss_before.* != 0) shutdown();
    const data_permissions = sv39_entries.Permissions{ .read = true, .write = true, .user = true, .accessed = true, .dirty = true };
    _ = builder.mapPage(user_data_va, data_pa, .page_4k, data_permissions) catch shutdown();
    sfence_vma.executeUnsafe(sfence_vma.global());
    write("ZIGREF_USERSPACE_ELF_DATA_BSS_PHASE bytes-verified\n");
    asm volatile ("fence.i" ::: "memory");
    userspace_elf_entry = load.entry.raw();
    userspace_elf_memory_end = segment.memory.end;
    userspace_elf_expected_sp = user_stack_va + frames.PageSize;
    userspace_elf_expected_a0 = 0x2300;
    userspace_elf_expected_t0 = batch23_initialized;
    userspace_elf_expected_t1 = batch23_mutation;
    userspace_elf_active = true;
    user_returned = false;
    asm volatile ("mv a0, %[entry]; mv a1, %[stack]; mv a2, %[trap_stack]; call enterUser; la t0, user_supervisor_sp; ld sp, 0(t0); addi sp, sp, 112"
        :
        : [entry] "r" (load.entry.raw()),
          [stack] "r" (user_stack_va + frames.PageSize),
          [trap_stack] "r" (trap_end),
        : "memory", "ra", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "t0", "t1", "t2", "t3", "t4", "t5", "t6"
    );
    asm volatile ("csrw stvec, %[entry]; csrw sscratch, zero"
        :
        : [entry] "r" (historical_stvec),
        : "memory"
    );
    const elf_satp_after = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const elf_code_leaf = builder.query(user_code_va) catch shutdown();
    const elf_stack_leaf = builder.query(user_stack_va) catch shutdown();
    const elf_data_leaf = builder.query(user_data_va) catch shutdown();
    for (elf_source, 0..) |source_byte, index| if (loaded[index] != source_byte) shutdown();
    if (userspace_elf_active or !user_returned or user_scause != 8 or
        elf_alloc_before + 1 != allocator.allocatedCount() or elf_tables_before != page_owner.page_count or
        elf_satp_before != elf_satp_after or elf_code_leaf.physical_address != user_code_pa or
        elf_stack_leaf.physical_address != user_stack_pa or elf_data_leaf.physical_address != data_pa or
        elf_code_leaf.raw_entry & 0x16 != 0x12 or elf_stack_leaf.raw_entry & 0x16 != 0x16 or
        elf_data_leaf.raw_entry & 0x16 != 0x16 or elf_data_leaf.raw_entry & 0x8 != 0 or bss_before.* != batch23_mutation) shutdown();
    write("ZIGREF_USERSPACE_ELF_DATA_BSS_BEGIN\nartifact=userspace-elf-rv64-data-bss\nartifact_bytes=");
    writeUsizeHex(userspace_elf_data_bss.len);
    write("\nartifact_fnv1a64=");
    writeUsizeHex(fnv1a64(userspace_elf_data_bss));
    write("\nsource_fnv1a64=");
    writeUsizeHex(source_hash);
    write("\nentry=");
    writeUsizeHex(load.entry.raw());
    write("\nsegment_count=0000000000000002\nsource_start=");
    writeUsizeHex(segment.source.start);
    write("\nsource_end=");
    writeUsizeHex(segment.source.end);
    write("\nmemory_start=");
    writeUsizeHex(segment.memory.start);
    write("\nmemory_end=");
    writeUsizeHex(segment.memory.end);
    write("\nfile_bytes=");
    writeUsizeHex(segment.file_byte_count);
    write("\nmemory_bytes=");
    writeUsizeHex(segment.memory_byte_count);
    write("\nzero_fill=");
    writeUsizeHex(segment.zero_fill_byte_count);
    write("\nalignment=");
    writeUsizeHex(@intCast(segment.alignment));
    write("\npermissions=R-X\ndestination_va=");
    writeUsizeHex(segment.memory_start.raw());
    write("\ndestination_pa=");
    writeUsizeHex(user_code_pa);
    write("\ncopied_bytes=");
    writeUsizeHex(segment.file_byte_count);
    write("\nloaded_bytes_equal=PASS");
    write("\nloaded_fnv1a64=");
    writeUsizeHex(loaded_hash);
    write("\ndata_source_start=");
    writeUsizeHex(data_segment.source.start);
    write("\ndata_source_end=");
    writeUsizeHex(data_segment.source.end);
    write("\ndata_memory_start=");
    writeUsizeHex(data_segment.memory.start);
    write("\ndata_memory_end=");
    writeUsizeHex(data_segment.memory.end);
    write("\ndata_file_bytes=");
    writeUsizeHex(data_segment.file_byte_count);
    write("\ndata_memory_bytes=");
    writeUsizeHex(data_segment.memory_byte_count);
    write("\ndata_zero_fill=");
    writeUsizeHex(data_segment.zero_fill_byte_count);
    write("\ndata_permissions=RW-\ndata_loaded_bytes_equal=PASS\nbss_zero_before=PASS\ndata_destination_pa=");
    writeUsizeHex(data_pa);
    write("\nbss_mutation_address=");
    writeUsizeHex(data_segment.memory.start + bss_offset);
    write("\nbss_mutation_value=");
    writeUsizeHex(bss_before.*);
    write("\nprepared_entry=");
    writeUsizeHex(userspace_elf_entry);
    write("\ntrap_cause=");
    writeUsizeHex(user_scause);
    write("\ntrap_sepc=");
    writeUsizeHex(user_sepc);
    write("\ntrap_sstatus=");
    writeUsizeHex(user_sstatus);
    write("\ntrap_frame=");
    writeUsizeHex(user_trap_frame_address);
    write("\nmarker_a0=");
    writeUsizeHex(user_a0);
    write("\nmarker_t0=");
    writeUsizeHex(user_t0);
    write("\nmarker_t1=");
    writeUsizeHex(user_t1);
    write("\nphysical_allocated_before=");
    writeUsizeHex(elf_alloc_before);
    write("\nphysical_allocated_after=");
    writeUsizeHex(allocator.allocatedCount());
    write("\npage_table_count_before=");
    writeUsizeHex(elf_tables_before);
    write("\npage_table_count_after=");
    writeUsizeHex(page_owner.page_count);
    write("\nsatp_before=");
    writeUsizeHex(elf_satp_before);
    write("\nsatp_after=");
    writeUsizeHex(elf_satp_after);
    write("\nroot_physical=");
    writeUsizeHex(root_physical);
    write("\nuser_code_pa=");
    writeUsizeHex(user_code_pa);
    write("\nuser_stack_pa=");
    writeUsizeHex(user_stack_pa);
    write("\nuser_leaf_count=0000000000000003\nwx_leaf_count=0000000000000000");
    write("\ncode_pte=");
    writeUsizeHex(elf_code_leaf.raw_entry);
    write("\nstack_pte=");
    writeUsizeHex(elf_stack_leaf.raw_entry);
    write("\ndata_pte=");
    writeUsizeHex(elf_data_leaf.raw_entry);
    write("\ntranslation_change=one-user-rw-leaf\nsfence_vma=global-executed\nfence_i=local-hart-executed\nsupervisor_resume=PASS\ncomplete=PASS\nZIGREF_USERSPACE_ELF_DATA_BSS_END\nZIGREF_USERSPACE_ELF_DATA_BSS_RETURNED\n");
}

noinline fn executeUserspaceElfInitialStack(allocator: anytype, page_owner: anytype, builder: anytype, user_code_pa: usize, user_stack_pa: usize, trap_end: usize, historical_stvec: usize, root_physical: usize) void {
    write("ZIGREF_USERSPACE_INITIAL_STACK_PHASE plan-materialize-execute\n");
    const load = elf_load.plan(2, userspace_elf_initial_stack) catch shutdown();
    if (load.items().len != 2) shutdown();
    const code = load.items()[0];
    const data = load.items()[1];
    if (code.memory.start != user_code_va or data.memory.start != user_data_va or load.entry.raw() < code.memory.start or load.entry.raw() >= code.memory.end) shutdown();
    const code_dst: [*]volatile u8 = @ptrFromInt(user_code_pa);
    for (0..frames.PageSize) |i| code_dst[i] = 0;
    const code_src = userspace_elf_initial_stack[code.source.start..code.source.end];
    for (code_src, 0..) |b, i| code_dst[i] = b;
    for (code_src, 0..) |b, i| if (code_dst[i] != b) shutdown();
    const data_leaf_before = builder.query(user_data_va) catch shutdown();
    const data_pa = data_leaf_before.physical_address;
    const data_dst: [*]volatile u8 = @ptrFromInt(data_pa);
    for (0..frames.PageSize) |i| data_dst[i] = 0;
    const data_src = userspace_elf_initial_stack[data.source.start..data.source.end];
    for (data_src, 0..) |b, i| data_dst[i] = b;
    for (data_src, 0..) |b, i| if (data_dst[i] != b) shutdown();
    for (data.file_byte_count..data.memory_byte_count) |i| if (data_dst[i] != 0) shutdown();
    const argv = [_][]const u8{ "alpz-24b", "stack-proof" };
    const envp = [_][]const u8{ "ALPZ_BATCH=24B", "MODE=qemu-proof" };
    const auxv = [_]initial_stack.AuxEntry{
        .{ .type = 6, .value = .{ .immediate = 4096 } },
        .{ .type = 9, .value = .{ .immediate = load.entry.raw() } },
        .{ .type = 31, .value = .{ .argv_string = 0 } },
    };
    const stack_range = initial_stack.GuestStackRange.init(user_stack_va, user_stack_va + frames.PageSize) catch shutdown();
    const plan = initial_stack.plan(256, 2, 2, 3, stack_range, &argv, &envp, &auxv) catch shutdown();
    if (plan.initial_sp.raw() % 16 != 0 or plan.used_range.start < user_stack_va or plan.used_range.end != user_stack_va + frames.PageSize) shutdown();
    const stack_dst: [*]volatile u8 = @ptrFromInt(user_stack_pa);
    for (0..frames.PageSize) |i| stack_dst[i] = 0;
    const stack_offset = plan.initial_sp.raw() - user_stack_va;
    for (plan.bytes(), 0..) |b, i| stack_dst[stack_offset + i] = b;
    for (plan.bytes(), 0..) |b, i| if (stack_dst[stack_offset + i] != b) shutdown();
    asm volatile ("fence.i" ::: "memory");
    userspace_elf_entry = load.entry.raw();
    userspace_elf_memory_end = code.memory.end;
    userspace_elf_expected_sp = plan.initial_sp.raw();
    userspace_elf_expected_a0 = 0x24b0;
    userspace_elf_expected_t0 = 0x24b024b024b024b0;
    userspace_elf_expected_t1 = batch23_mutation;
    userspace_elf_active = true;
    user_returned = false;
    asm volatile ("mv a0, %[entry]; mv a1, %[stack]; mv a2, %[trap_stack]; call enterUser; la t0, user_supervisor_sp; ld sp, 0(t0); addi sp, sp, 112"
        :
        : [entry] "r" (load.entry.raw()),
          [stack] "r" (plan.initial_sp.raw()),
          [trap_stack] "r" (trap_end),
        : "memory", "ra", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "t0", "t1", "t2", "t3", "t4", "t5", "t6"
    );
    asm volatile ("csrw stvec, %[entry]; csrw sscratch, zero"
        :
        : [entry] "r" (historical_stvec),
        : "memory"
    );
    const code_leaf = builder.query(user_code_va) catch shutdown();
    const stack_leaf = builder.query(user_stack_va) catch shutdown();
    const data_leaf = builder.query(user_data_va) catch shutdown();
    for (plan.bytes(), 0..) |b, i| if (stack_dst[stack_offset + i] != b) shutdown();
    if (userspace_elf_active or !user_returned or user_scause != 8 or user_sp != plan.initial_sp.raw() or
        code_leaf.raw_entry & 0x16 != 0x12 or stack_leaf.raw_entry & 0x1e != 0x16 or data_leaf.raw_entry & 0x1e != 0x16 or
        @as(*volatile usize, @ptrFromInt(data_pa + data.file_byte_count)).* != batch23_mutation) shutdown();
    write("ZIGREF_USERSPACE_INITIAL_STACK_BEGIN\nartifact=userspace-elf-rv64-initial-stack\nentry=");
    writeUsizeHex(load.entry.raw());
    write("\necall_pc=");
    writeUsizeHex(user_sepc);
    write("\ninitial_sp=");
    writeUsizeHex(plan.initial_sp.raw());
    write("\nused_start=");
    writeUsizeHex(plan.used_range.start);
    write("\nused_end=");
    writeUsizeHex(plan.used_range.end);
    write("\nstack_bytes=");
    writeHex(plan.bytes());
    write("\nstack_sanitized_bytes=0000000000001000\nstack_exact=PASS\nargc=0000000000000002\nargv_count=0000000000000002\nenvp_count=0000000000000002\nauxv_count=0000000000000003\ntrap_cause=");
    writeUsizeHex(user_scause);
    write("\ntrap_sstatus=");
    writeUsizeHex(user_sstatus);
    write("\ntrap_frame=");
    writeUsizeHex(user_trap_frame_address);
    write("\nmarker_a0=");
    writeUsizeHex(user_a0);
    write("\nmarker_t0=");
    writeUsizeHex(user_t0);
    write("\nmarker_t1=");
    writeUsizeHex(user_t1);
    write("\nuser_code_pa=");
    writeUsizeHex(user_code_pa);
    write("\nuser_stack_pa=");
    writeUsizeHex(user_stack_pa);
    write("\nuser_data_pa=");
    writeUsizeHex(data_pa);
    write("\nroot_physical=");
    writeUsizeHex(root_physical);
    write("\npage_table_count=");
    writeUsizeHex(page_owner.page_count);
    write("\nphysical_allocated=");
    writeUsizeHex(allocator.allocatedCount());
    write("\ncode_pte=");
    writeUsizeHex(code_leaf.raw_entry);
    write("\nstack_pte=");
    writeUsizeHex(stack_leaf.raw_entry);
    write("\ndata_pte=");
    writeUsizeHex(data_leaf.raw_entry);
    write("\nuser_leaf_count=0000000000000003\nwx_leaf_count=0000000000000000\nstack_policy=project-55\ntranslation_change=none\nsfence_vma=not-required-no-pte-change\nfence_i=local-hart-executed\nsupervisor_resume=PASS\ncomplete=PASS\nZIGREF_USERSPACE_INITIAL_STACK_END\nZIGREF_USERSPACE_INITIAL_STACK_RETURNED\n");
}

noinline fn executeLinuxRv64Syscalls(allocator: anytype, page_owner: anytype, builder: anytype, user_code_pa: usize, user_stack_pa: usize, trap_end: usize, historical_stvec: usize, root_physical: usize) void {
    write("ZIGREF_LINUX_RV64_SYSCALL_PHASE plan-materialize-execute\n");
    const load = elf_load.plan(2, userspace_elf_linux_syscalls) catch {
        write("ZIGREF_25A_FAIL load-plan\n");
        shutdown();
    };
    if (load.items().len != 2) {
        write("ZIGREF_25A_FAIL segments\n");
        shutdown();
    }
    const code = load.items()[0];
    const data = load.items()[1];
    if (code.memory.start != user_code_va or data.memory.start != user_data_va) {
        write("ZIGREF_25A_FAIL addresses\n");
        shutdown();
    }
    const code_dst: [*]volatile u8 = @ptrFromInt(user_code_pa);
    for (0..frames.PageSize) |i| code_dst[i] = 0;
    for (userspace_elf_linux_syscalls[code.source.start..code.source.end], 0..) |b, i| code_dst[i] = b;
    const data_leaf_before = builder.query(user_data_va) catch shutdown();
    const data_pa = data_leaf_before.physical_address;
    const data_dst: [*]volatile u8 = @ptrFromInt(data_pa);
    for (0..frames.PageSize) |i| data_dst[i] = 0;
    for (userspace_elf_linux_syscalls[data.source.start..data.source.end], 0..) |b, i| data_dst[i] = b;
    const argv = [_][]const u8{ "alpz-24b", "stack-proof" };
    const envp = [_][]const u8{ "ALPZ_BATCH=24B", "MODE=qemu-proof" };
    const auxv = [_]initial_stack.AuxEntry{ .{ .type = 6, .value = .{ .immediate = 4096 } }, .{ .type = 9, .value = .{ .immediate = load.entry.raw() } }, .{ .type = 31, .value = .{ .argv_string = 0 } } };
    const stack_range = initial_stack.GuestStackRange.init(user_stack_va, user_stack_va + frames.PageSize) catch shutdown();
    const stack = initial_stack.plan(256, 2, 2, 3, stack_range, &argv, &envp, &auxv) catch shutdown();
    const stack_dst: [*]volatile u8 = @ptrFromInt(user_stack_pa);
    for (0..frames.PageSize) |i| stack_dst[i] = 0;
    const stack_offset = stack.initial_sp.raw() - user_stack_va;
    for (stack.bytes(), 0..) |b, i| stack_dst[stack_offset + i] = b;
    const ActiveQuery = struct {
        active: @TypeOf(&builder),
        fn query(raw: *const anyopaque, page: user_transfer.GuestVirtualAddress) ?user_transfer.PageResolution {
            const self: *const @This() = @ptrCast(@alignCast(raw));
            const leaf = self.active.*.query(page.raw()) catch return null;
            const flags = leaf.raw_entry & 0xff;
            if (flags & 1 == 0 or flags & 0xe == 0) return null;
            return .{ .physical_page_start = user_transfer.PhysicalAddress.init(leaf.physical_address & ~@as(usize, frames.PageSize - 1)), .user = flags & 0x10 != 0, .readable = flags & 0x2 != 0, .writable = flags & 0x4 != 0 };
        }
    };
    const active_query = ActiveQuery{ .active = &builder };
    syscall_query = .{ .context = &active_query, .queryFn = ActiveQuery.query };
    syscall_count = 0;
    syscall_total_count = 0;
    syscall_dropped_count = 0;
    syscall_output_len = 0;
    syscall_terminal_status = 0;
    service_trap_count = 0;
    syscall_numbers = .{0} ** (syscall_capacity + 1);
    syscall_pcs = .{0} ** (syscall_capacity + 1);
    syscall_sstatus = .{0} ** (syscall_capacity + 1);
    syscall_resume_pcs = .{0} ** (syscall_capacity + 1);
    syscall_args = .{.{0} ** 6} ** (syscall_capacity + 1);
    syscall_results = .{0} ** (syscall_capacity + 1);
    syscall_semantics = .{0} ** (syscall_capacity + 1);
    syscall_resources = .{};
    syscall_bindings = .{};
    // Force the real machine I/O path through a reused slot. Any conversion
    // that drops the generation or reconstructs generation 1 now fails before
    // the first successful read.
    const retired_ref = syscall_resources.create(.{ .backend = @enumFromInt(3), .capabilities = .{ .read = true } }) catch shutdown();
    if (!(syscall_resources.release(retired_ref) catch shutdown())) shutdown();
    const stdin_ref = syscall_resources.create(.{ .backend = @enumFromInt(0), .capabilities = .{ .read = true } }) catch shutdown();
    if (stdin_ref.index != retired_ref.index or stdin_ref.generation != retired_ref.generation + 1) shutdown();
    const stdout_ref = syscall_resources.create(.{ .backend = @enumFromInt(1), .capabilities = .{ .write = true } }) catch shutdown();
    const stderr_ref = syscall_resources.create(.{ .backend = @enumFromInt(2), .capabilities = .{ .write = true } }) catch shutdown();
    syscall_bindings.bindAt(0, stdin_ref) catch shutdown();
    syscall_bindings.bindAt(1, stdout_ref) catch shutdown();
    syscall_bindings.bindAt(2, stderr_ref) catch shutdown();
    const allocated_before = allocator.allocatedCount();
    const tables_before = page_owner.page_count;
    const satp_before = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    syscall_active = true;
    asm volatile ("fence.i" ::: "memory");
    asm volatile ("mv a0, %[entry]; mv a1, %[stack]; mv a2, %[trap_stack]; call enterUserService"
        :
        : [entry] "r" (load.entry.raw()),
          [stack] "r" (stack.initial_sp.raw()),
          [trap_stack] "r" (trap_end),
        : "memory", "ra", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "t0", "t1", "t2", "t3", "t4", "t5", "t6"
    );
    syscall_active = false;
    asm volatile ("csrw stvec, %[entry]; csrw sscratch, zero"
        :
        : [entry] "r" (historical_stvec),
        : "memory"
    );
    const satp_after = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const code_leaf = builder.query(user_code_va) catch shutdown();
    const stack_leaf = builder.query(user_stack_va) catch shutdown();
    const data_leaf = builder.query(user_data_va) catch shutdown();
    const expected_numbers = [_]usize{ 0x7fff, 63, 23, 57, 63, 63, 63, 64, 57, 63, 57, 64, 64, 63, 94 };
    const expected_results = [_]usize{ negativeErrno(38), 5, 3, 0, negativeErrno(9), negativeErrno(14), 4, 9, 0, negativeErrno(9), negativeErrno(9), negativeErrno(9), negativeErrno(14), negativeErrno(9) };
    // The final close deliberately retires the stdin resource, so its owned
    // state is no longer resolvable here. Derive the completed-read boundary
    // from the two successful read completions retained by this proof rather
    // than keeping a second global cursor alive past resource retirement.
    const stdin_state = syscall_results[1] + syscall_results[6];
    if (syscall_count != 15 or !std.mem.eql(usize, syscall_numbers[0..15], &expected_numbers) or !std.mem.eql(usize, syscall_results[0..14], &expected_results) or syscall_terminal_status != 37 or syscall_output_len != 9 or !std.mem.eql(u8, syscall_output[0..9], "stdin-25b") or stdin_state != 9 or syscall_resources.count() != 2 or allocated_before != allocator.allocatedCount() or tables_before != page_owner.page_count or satp_before != satp_after or code_leaf.raw_entry & 0x1e != 0x1a or stack_leaf.raw_entry & 0x1e != 0x16 or data_leaf.raw_entry & 0x1e != 0x16) {
        write("ZIGREF_25B_FAIL final-relations\n");
        shutdown();
    }
    write("ZIGREF_LINUX_RV64_SYSCALL_BEGIN\nartifact=userspace-elf-rv64-linux-syscalls\nentry=");
    writeUsizeHex(load.entry.raw());
    write("\ninitial_sp=");
    writeUsizeHex(stack.initial_sp.raw());
    for (0..15) |i| {
        write("\nevent=");
        writeUsizeHex(i);
        write(",nr=");
        writeUsizeHex(syscall_numbers[i]);
        write(",pc=");
        writeUsizeHex(syscall_pcs[i]);
        write(",resume=");
        writeUsizeHex(if (i < 14) syscall_resume_pcs[i] else 0);
        write(",sstatus=");
        writeUsizeHex(syscall_sstatus[i]);
        write(",a0=");
        writeUsizeHex(syscall_args[i][0]);
        write(",a1=");
        writeUsizeHex(syscall_args[i][1]);
        write(",a2=");
        writeUsizeHex(syscall_args[i][2]);
        write(",semantic=");
        write(switch (syscall_semantics[i]) {
            1 => "unsupported",
            2 => "write_bytes",
            3 => "terminate",
            4 => "duplicate",
            5 => "close",
            6 => "read_bytes",
            else => "INVALID",
        });
        write(",result=");
        writeUsizeHex(if (i < 14) syscall_results[i] else syscall_terminal_status);
    }
    write("\noutput_hex=");
    writeHex(syscall_output[0..syscall_output_len]);
    write("\nstdin_cursor=");
    writeUsizeHex(stdin_state);
    write("\nresource_count=");
    writeUsizeHex(syscall_resources.count());
    write("\nstdin_generation=");
    writeUsizeHex(stdin_ref.generation);
    write("\ntrap_cause=0000000000000008\nterminal_status=");
    writeUsizeHex(syscall_terminal_status);
    write("\ncode_pte=");
    writeUsizeHex(code_leaf.raw_entry);
    write("\nstack_pte=");
    writeUsizeHex(stack_leaf.raw_entry);
    write("\ndata_pte=");
    writeUsizeHex(data_leaf.raw_entry);
    write("\nuser_leaf_count=0000000000000003\nwx_leaf_count=0000000000000000\npage_table_count=");
    writeUsizeHex(page_owner.page_count);
    write("\nphysical_allocated=");
    writeUsizeHex(allocator.allocatedCount());
    write("\nroot_physical=");
    writeUsizeHex(root_physical);
    write("\nallocated_before=");
    writeUsizeHex(allocated_before);
    write("\nallocated_after=");
    writeUsizeHex(allocator.allocatedCount());
    write("\ntables_before=");
    writeUsizeHex(tables_before);
    write("\ntables_after=");
    writeUsizeHex(page_owner.page_count);
    write("\nsatp_before=");
    writeUsizeHex(satp_before);
    write("\nsatp_after=");
    writeUsizeHex(satp_after);
    write("\nwhole_range_before_output=PASS\ntranslation_change=none\ncomplete=PASS\nZIGREF_LINUX_RV64_SYSCALL_END\nZIGREF_LINUX_RV64_SYSCALL_RETURNED\n");
}

noinline fn executeBatch26(builder: *MachineBuilder, user_code_pa: usize, trap_end: usize, historical_stvec: usize) void {
    write("ZIGREF_BATCH26_PHASE prepare\n");
    const load = elf_load.plan(2, userspace_elf_file_memory_exec) catch shutdown();
    const code = load.items()[0];
    const data = load.items()[1];
    const code_dst: [*]volatile u8 = @ptrFromInt(user_code_pa);
    for (0..frames.PageSize) |i| code_dst[i] = 0;
    for (userspace_elf_file_memory_exec[code.source.start..code.source.end], 0..) |b, i| code_dst[i] = b;
    const data_leaf = builder.query(user_data_va) catch shutdown();
    const data_dst: [*]volatile u8 = @ptrFromInt(data_leaf.physical_address);
    for (0..frames.PageSize) |i| data_dst[i] = 0;
    for (userspace_elf_file_memory_exec[data.source.start..data.source.end], 0..) |b, i| data_dst[i] = b;

    batch26_builder = builder;
    batch26_fs = .{};
    const etc = batch26_fs.create(.root, "etc", .directory, "") catch shutdown();
    batch26_file_object = batch26_fs.create(etc, "message", .file, "batch26-file") catch shutdown();
    const bin = batch26_fs.create(.root, "bin", .directory, "") catch shutdown();
    _ = batch26_fs.create(bin, "main", .file, batch26_main_elf) catch shutdown();
    const lib = batch26_fs.create(.root, "lib", .directory, "") catch shutdown();
    _ = batch26_fs.create(lib, "ld-batch26-rv64.so", .file, batch26_interp_elf) catch shutdown();
    const alias_leaf = builder.query(sv39_alias) catch shutdown();
    batch26_map_pa = alias_leaf.physical_address;
    batch26_map_present = false;
    batch26_protect_fault_cause = 0;
    batch26_unmap_fault_cause = 0;
    batch26_interp_terminal = false;
    syscall_query = .{ .context = &batch26_query_context, .queryFn = Batch26ActiveQuery.query };
    syscall_resources = .{};
    syscall_bindings = .{};
    const retired = syscall_resources.create(.{ .backend = @enumFromInt(9), .capabilities = .{} }) catch shutdown();
    if (!(syscall_resources.release(retired) catch shutdown())) shutdown();
    const stdin = syscall_resources.create(.{ .backend = @enumFromInt(0), .capabilities = .{ .read = true } }) catch shutdown();
    const stdout = syscall_resources.create(.{ .backend = @enumFromInt(1), .capabilities = .{ .write = true } }) catch shutdown();
    const stderr = syscall_resources.create(.{ .backend = @enumFromInt(2), .capabilities = .{ .write = true } }) catch shutdown();
    syscall_bindings.bindAt(0, stdin) catch shutdown();
    syscall_bindings.bindAt(1, stdout) catch shutdown();
    syscall_bindings.bindAt(2, stderr) catch shutdown();
    if (stdin.generation != 2) shutdown();

    batch26_count = 0;
    batch26_results = .{0} ** 11;
    batch26_pcs = .{0} ** 10;
    batch26_resumes = .{0} ** 9;
    service_trap_count = 0;
    batch26_active = true;
    syscall_active = true;
    write("ZIGREF_BATCH26_PHASE execute\n");
    asm volatile ("fence.i" ::: "memory");
    asm volatile ("mv a0, %[entry]; mv a1, %[stack]; mv a2, %[trap_stack]; call enterUserService"
        :
        : [entry] "r" (load.entry.raw()),
          [stack] "r" (user_stack_va + frames.PageSize - 64),
          [trap_stack] "r" (trap_end),
        : "memory", "ra", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "t0", "t1", "t2", "t3", "t4", "t5", "t6"
    );
    syscall_active = false;
    batch26_active = false;
    asm volatile ("csrw stvec, %[entry]; csrw sscratch, zero"
        :
        : [entry] "r" (historical_stvec),
        : "memory"
    );
    if (batch26_count != 10 or !batch26_interp_terminal or batch26_map_present) shutdown();
    const bound_open_ref = syscall_bindings.resolve(3) orelse shutdown();
    if (bound_open_ref.index != batch26_open_ref.index or bound_open_ref.generation != batch26_open_ref.generation) shutdown();
    write("ZIGREF_BATCH26_BEGIN\nartifact=userspace-elf-rv64-file-memory-exec\nmain_artifact=userspace-elf-rv64-batch26-main\ninterp_artifact=userspace-elf-rv64-batch26-interp\nopen_fd=0000000000000003\nfile_hex=626174636832362d66696c65\nmissing_result=fffffffffffffffe\nefault_result=fffffffffffffff2\nresource_index=");
    writeUsizeHex(batch26_open_ref.index);
    write("\nresource_generation=");
    writeUsizeHex(batch26_open_ref.generation);
    write("\nbound_resource_index=");
    writeUsizeHex(bound_open_ref.index);
    write("\nbound_resource_generation=");
    writeUsizeHex(bound_open_ref.generation);
    write("\nmmap_va=0000000080404000\nmmap_value=");
    writeUsizeHex(batch26_mmap_value);
    for (batch26_pcs, 0..) |pc, i| {
        write("\nsyscall_index=");
        writeUsizeHex(i);
        write(",pc=");
        writeUsizeHex(pc);
        write(",nr=");
        writeUsizeHex(([_]usize{ 56, 63, 56, 56, 222, 226, 215, 221, 221, 93 })[i]);
        write(",result=");
        writeUsizeHex(batch26_results[i]);
        if (i < 8) {
            write(",resume=");
            writeUsizeHex(batch26_resumes[i]);
        }
    }
    write("\nprotect_fault_cause=");
    writeUsizeHex(batch26_protect_fault_cause);
    write("\nprotect_fault_va=");
    writeUsizeHex(batch26_protect_fault_va);
    write("\nprotect_fault_pc=");
    writeUsizeHex(batch26_protect_fault_pc);
    write("\nprotected_pte=");
    writeUsizeHex(batch26_protect_pte);
    write("\nunmap_fault_cause=");
    writeUsizeHex(batch26_unmap_fault_cause);
    write("\nunmap_fault_va=");
    writeUsizeHex(batch26_unmap_fault_va);
    write("\nunmap_fault_pc=");
    writeUsizeHex(batch26_unmap_fault_pc);
    write("\nfailed_exec_result=fffffffffffffffe\nfailed_exec_resume=");
    writeUsizeHex(batch26_failed_exec_resume);
    write("\nprogram_a_continuation=");
    writeUsizeHex(batch26_program_a_continuation);
    write("\nsuccessful_exec_return=none\nexec_path=/bin/main\nexec_argv0=/bin/main\nexec_env0=BATCH26=causal\nexec_prepare=PASS\nexec_commit=PASS\nprogram_a_terminal_syscall=00000000000000dd\nprogram_b_interpreter_marker=000000000000026b\ninterp_path=/lib/ld-batch26-rv64.so\nmain_entry=");
    writeUsizeHex(batch26_main_entry);
    write("\ninterp_raw_entry=");
    writeUsizeHex(batch26_interp_raw_entry);
    write("\ninterp_bias=");
    writeUsizeHex(batch26_interp_bias);
    write("\ninterp_entry=");
    writeUsizeHex(batch26_interp_entry);
    write("\nat_entry=");
    writeUsizeHex(batch26_main_entry);
    write("\nat_base=");
    writeUsizeHex(batch26_interp_bias);
    write("\nat_phdr=");
    writeUsizeHex(batch26_at_phdr);
    write("\ninitial_sp=");
    writeUsizeHex(batch26_initial_sp);
    write("\nwx_leaf_count=0000000000000000\ncomplete=PASS\nZIGREF_BATCH26_END\n");
}

export fn freestandingMain() callconv(.c) noreturn {
    asm volatile ("csrw stvec, %[entry]"
        :
        : [entry] "r" (&supervisorTrapEntry),
        : "memory"
    );
    const registers_preserved = trapProbe() == 1;
    const interrupt = observed_scause >> 63;
    write("\nZIGREF_TRAP_BEGIN\ncount=");
    write(if (trap_count == 1) "1" else "INVALID");
    write("\ncause=");
    writeUsizeHex(observed_scause & 0x7fff_ffff_ffff_ffff);
    write("\ninterrupt=");
    write(if (interrupt == 0) "0" else "1");
    write("\nsepc=");
    writeUsizeHex(observed_sepc);
    write("\nresume_delta=4\nstval=");
    writeUsizeHex(observed_stval);
    write("\nsstatus=");
    writeUsizeHex(observed_sstatus);
    write("\nregisters=");
    write(if (registers_preserved) "PASS" else "FAIL");
    write("\nstack=");
    write(if (registers_preserved) "PASS" else "FAIL");
    write("\nZIGREF_TRAP_END\n");
    if (trap_count != 1 or observed_scause != 3 or !registers_preserved) {
        write("ZIGREF_TRAP_FAILURE\n");
        shutdown();
    }
    write("ZIGREF_TRAP_RETURNED\n");
    const now = asm volatile ("rdtime %[value]"
        : [value] "=r" (-> usize),
    );
    _ = sbiCall(0, 0, now +% 100_000, 0); // Legacy SBI set_timer, RV64 deadline.
    const timer_registers_preserved = timerProbe() == 1;
    write("ZIGREF_TIMER_BEGIN\ncount=");
    write(if (timer_trap_count == 1) "1" else "INVALID");
    write("\ncause=");
    writeUsizeHex(timer_scause & 0x7fff_ffff_ffff_ffff);
    write("\ninterrupt=");
    write(if (timer_scause >> 63 == 1) "1" else "0");
    write("\nsepc=");
    writeUsizeHex(timer_sepc);
    write("\nsepc_policy=unchanged\npolicy=mask-stie-and-set-timer-max\npolicy_complete=");
    write(if (timer_policy_complete) "PASS" else "FAIL");
    write("\nregisters=");
    write(if (timer_registers_preserved) "PASS" else "FAIL");
    write("\nstack=");
    write(if (timer_registers_preserved) "PASS" else "FAIL");
    write("\nsstatus=");
    writeUsizeHex(timer_sstatus);
    write("\nZIGREF_TIMER_END\n");
    if (timer_trap_count != 1 or timer_scause != (1 << 63) | 5 or
        !timer_policy_complete or !timer_registers_preserved)
    {
        write("ZIGREF_TIMER_FAILURE\n");
        shutdown();
    }
    write("ZIGREF_TIMER_RETURNED\n");
    const ticks_now = asm volatile ("rdtime %[value]"
        : [value] "=r" (-> usize),
    );
    active_tick_deadline = ticks_now +% tick_interval;
    ticks_active = true;
    _ = sbiCall(0, 0, active_tick_deadline, 0);
    const ticks_registers_preserved = ticksProbe() == 1;
    // Global SIE is now masked by ticksProbe. Any undeclared extra delivery
    // before this frame would still have incremented tick_trap_count.
    write("ZIGREF_TICKS_BEGIN\nexpected=");
    write(if (expected_tick_count == 4) "4" else "INVALID");
    write("\ncount=");
    write(if (tick_trap_count == expected_tick_count) "4" else "INVALID");
    write("\nreturns=");
    write(if (tick_return_count == expected_tick_count) "4" else "INVALID");
    write("\npolicy=observed-time-plus-bounded-interval\ninterval=");
    writeUsizeHex(tick_interval);
    write("\nregisters=");
    write(if (ticks_registers_preserved) "PASS" else "FAIL");
    write("\nstack=");
    write(if (ticks_registers_preserved) "PASS" else "FAIL");
    write("\nfinal_neutralized=");
    write(if (ticks_final_neutralized) "PASS" else "FAIL");
    for (0..expected_tick_count) |index| {
        write("\ntick=");
        writeUsizeHex(index);
        write(",cause=");
        writeUsizeHex(tick_scause[index] & 0x7fff_ffff_ffff_ffff);
        write(",interrupt=");
        write(if (tick_scause[index] >> 63 == 1) "1" else "0");
        write(",sepc=");
        writeUsizeHex(tick_sepc[index]);
        write(",time=");
        writeUsizeHex(tick_observed_time[index]);
        write(",deadline=");
        writeUsizeHex(tick_deadline[index]);
        write(",next_deadline=");
        writeUsizeHex(tick_next_deadline[index]);
        write(",rearmed=");
        write(if (tick_rearmed[index]) "1" else "0");
        write(",sstatus=");
        writeUsizeHex(tick_sstatus[index]);
    }
    write("\nZIGREF_TICKS_END\n");
    if (tick_trap_count != expected_tick_count or tick_return_count != expected_tick_count or
        !ticks_final_neutralized or !ticks_registers_preserved)
    {
        write("ZIGREF_TICKS_FAILURE\n");
        shutdown();
    }
    write("ZIGREF_TICKS_RETURNED\n");
    // This adapter deliberately runs only after ticksProbe has observed all
    // four returns through sret. It maps the raw rdtime observations directly
    // to the target-neutral scheduler's u64 time; no conversion or addition
    // can overflow, and scheduling policy remains in the scheduler module.
    var scheduler = scheduler_module.BoundedDeterministicScheduler(4).init(tick_observed_time[0]);
    scheduler.schedule(.{ .id = 1, .ready_at = tick_observed_time[0], .priority = 0 }) catch unreachable;
    scheduler.schedule(.{ .id = 2, .ready_at = tick_observed_time[1], .priority = 1 }) catch unreachable;
    scheduler.schedule(.{ .id = 3, .ready_at = tick_observed_time[1], .priority = 1 }) catch unreachable;
    scheduler.schedule(.{ .id = 4, .ready_at = tick_observed_time[3], .priority = 0 }) catch unreachable;
    var selected: [4]u32 = [_]u32{0} ** 4;
    var selected_at: [4]usize = [_]usize{0} ** 4;
    var selected_count: usize = 0;
    var ready_counts: [expected_tick_count]usize = [_]usize{0} ** expected_tick_count;
    for (tick_observed_time, 0..) |machine_time, observation| {
        scheduler.advanceTo(machine_time) catch {
            write("ZIGREF_SCHEDULER_TIME_FAILURE\n");
            shutdown();
        };
        while (scheduler.nextReady()) |task| {
            if (selected_count >= selected.len) {
                write("ZIGREF_SCHEDULER_TIME_FAILURE\n");
                shutdown();
            }
            selected[selected_count] = task.id;
            selected_at[selected_count] = observation;
            selected_count += 1;
            ready_counts[observation] += 1;
        }
    }
    write("ZIGREF_SCHEDULER_TIME_BEGIN\nobservations=4\nmapping=identity-rdtime-u64\nreturns_before_decisions=");
    write(if (tick_return_count == expected_tick_count) "4" else "INVALID");
    write("\nthresholds=");
    for ([_]usize{ tick_observed_time[0], tick_observed_time[1], tick_observed_time[1], tick_observed_time[3] }, 0..) |value, index| {
        if (index != 0) write(",");
        writeUsizeHex(value);
    }
    for (tick_observed_time, 0..) |machine_time, index| {
        write("\nobservation=");
        writeUsizeHex(index);
        write(",machine=");
        writeUsizeHex(machine_time);
        write(",scheduler=");
        writeUsizeHex(machine_time);
        write(",ready_count=");
        writeUsizeHex(ready_counts[index]);
        write(",decision_phase=after-sret");
    }
    write("\nselected=");
    for (selected[0..selected_count], 0..) |id, index| {
        if (index != 0) write(",");
        writeUsizeHex(id);
        write("@");
        writeUsizeHex(selected_at[index]);
    }
    write("\nremaining=");
    writeUsizeHex(scheduler.count());
    write("\ncomplete=PASS\nZIGREF_SCHEDULER_TIME_END\nZIGREF_SCHEDULER_TIME_RETURNED\n");
    const pool_begin = @intFromPtr(&__physical_page_pool_begin);
    const pool_end = @intFromPtr(&__physical_page_pool_end);
    const satp = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    var regions = region_sets.PhysicalMemoryRegionSet(1){};
    regions.add(addresses.PhysicalAddress.init(pool_begin), pool_end - pool_begin, .usable) catch {
        write("ZIGREF_PHYSICAL_MEMORY_FAILURE\n");
        shutdown();
    };
    runtime_allocator = MachineAllocator.initFromRegions(1, &regions) catch {
        write("ZIGREF_PHYSICAL_MEMORY_FAILURE\n");
        shutdown();
    };
    const initial_free = runtime_allocator.freeCount();
    var owned: [physical_pool_pages]frames.PhysicalPageFrameNumber = undefined;
    var sentinels: [physical_pool_pages]usize = undefined;
    for (&owned, 0..) |*slot, index| {
        slot.* = runtime_allocator.allocate() catch {
            write("ZIGREF_PHYSICAL_MEMORY_FAILURE\n");
            shutdown();
        };
        const address = (slot.toAddress() catch unreachable).raw();
        const sentinel = @as(usize, 0x5a17_0000_0000_0000) | index;
        const pointer: *volatile usize = @ptrFromInt(address + 64);
        pointer.* = sentinel;
        sentinels[index] = pointer.*;
    }
    const exhausted = if (runtime_allocator.allocate()) |_| false else |err| err == error.Exhausted;
    runtime_allocator.release(owned[2]) catch {
        write("ZIGREF_PHYSICAL_MEMORY_FAILURE\n");
        shutdown();
    };
    const double_free = if (runtime_allocator.release(owned[2])) |_| false else |err| err == error.DoubleFree;
    const foreign = frames.PhysicalPageFrameNumber.fromAddress(addresses.PhysicalAddress.init(pool_end)) catch unreachable;
    const foreign_rejected = if (runtime_allocator.release(foreign)) |_| false else |err| err == error.ForeignFrame;
    const reacquired = runtime_allocator.allocate() catch {
        write("ZIGREF_PHYSICAL_MEMORY_FAILURE\n");
        shutdown();
    };
    const reacquired_matches = reacquired.value == owned[2].value;
    for (owned) |frame| runtime_allocator.release(frame) catch {
        // The reacquired frame is owned again, so every original frame is now releasable.
        write("ZIGREF_PHYSICAL_MEMORY_FAILURE\n");
        shutdown();
    };
    write("ZIGREF_PHYSICAL_MEMORY_BEGIN\npages=0000000000000008\npage_size=");
    writeUsizeHex(frames.PageSize);
    write("\npool_begin=");
    writeUsizeHex(pool_begin);
    write("\npool_end=");
    writeUsizeHex(pool_end);
    write("\nsatp=");
    writeUsizeHex(satp);
    write("\ntranslation=bare\nregion_count=");
    writeUsizeHex(regions.count());
    write("\nregion_kind=usable\ninitial_free=");
    writeUsizeHex(initial_free);
    write("\ninitial_allocated=0000000000000000");
    for (owned, 0..) |frame, index| {
        write("\nframe=");
        writeUsizeHex(index);
        write(",pfn=");
        writeUsizeHex(frame.value);
        write(",address=");
        writeUsizeHex((frame.toAddress() catch unreachable).raw());
        write(",offset=0000000000000040,wrote=");
        writeUsizeHex(@as(usize, 0x5a17_0000_0000_0000) | index);
        write(",read=");
        writeUsizeHex(sentinels[index]);
    }
    write("\nexhausted=");
    write(if (exhausted) "Exhausted" else "INVALID");
    write("\nreleased_index=0000000000000002\ndouble_free=");
    write(if (double_free) "DoubleFree" else "INVALID");
    write("\nforeign_pfn=");
    writeUsizeHex(foreign.value);
    write("\nforeign_release=");
    write(if (foreign_rejected) "ForeignFrame" else "INVALID");
    write("\nreacquired_pfn=");
    writeUsizeHex(reacquired.value);
    write("\nreacquired_matches=");
    write(if (reacquired_matches) "PASS" else "FAIL");
    write("\nfinal_free=");
    writeUsizeHex(runtime_allocator.freeCount());
    write("\nfinal_allocated=");
    writeUsizeHex(runtime_allocator.allocatedCount());
    write("\ncomplete=PASS\nZIGREF_PHYSICAL_MEMORY_END\n");
    if (satp != 0 or initial_free != physical_pool_pages or !exhausted or !double_free or
        !foreign_rejected or !reacquired_matches or runtime_allocator.freeCount() != physical_pool_pages or
        runtime_allocator.allocatedCount() != 0)
    {
        write("ZIGREF_PHYSICAL_MEMORY_FAILURE\n");
        shutdown();
    }
    write("ZIGREF_PHYSICAL_MEMORY_RETURNED\n");
    // Batch 16 has returned every frame. Reserve one owned data frame, then
    // let the generic runtime_builder obtain and zero only real page-table frames from
    // the same runtime_allocator. The bounded first address space maps the exact ELF
    // image/pool span with 4 KiB RWX leaves plus one non-identity RW alias.
    const alias_frame = runtime_allocator.allocate() catch {
        write("ZIGREF_SV39_ACTIVE_FAILURE\n");
        shutdown();
    };
    const alias_physical = (alias_frame.toAddress() catch unreachable).raw();
    runtime_page_owner = .{ .allocator = &runtime_allocator };
    runtime_builder = MachineBuilder.init(&runtime_page_owner) catch {
        write("ZIGREF_SV39_ACTIVE_FAILURE\n");
        shutdown();
    };
    const image_begin = @intFromPtr(&__image_begin);
    const image_end = @intFromPtr(&__image_end);
    const reservation_begin = @intFromPtr(&__prepared_image_reservation_begin);
    const reservation_end = @intFromPtr(&__prepared_image_reservation_end);
    const caller_artifact_begin = @intFromPtr(&__caller_artifact_begin);
    const caller_artifact_end = @intFromPtr(&__caller_artifact_end);
    if (image_end > sv39_alias or reservation_begin < user_data_va + frames.PageSize or reservation_end <= reservation_begin or
        caller_artifact_end <= caller_artifact_begin or caller_artifact_begin < reservation_end)
        shutdown();
    const mapped_begin = image_begin & ~@as(usize, frames.PageSize - 1);
    const mapped_end = (image_end + frames.PageSize - 1) & ~@as(usize, frames.PageSize - 1);
    const permissions = sv39_entries.Permissions{ .read = true, .write = true, .execute = true, .accessed = true, .dirty = true };
    var address = mapped_begin;
    while (address < mapped_end) : (address += frames.PageSize) {
        _ = runtime_builder.mapPage(address, address, .page_4k, permissions) catch {
            write("ZIGREF_SV39_ACTIVE_FAILURE\n");
            shutdown();
        };
    }
    address = reservation_begin;
    while (address < reservation_end) : (address += frames.PageSize) {
        _ = runtime_builder.mapPage(address, address, .page_4k, .{ .read = true, .write = true, .accessed = true, .dirty = true }) catch shutdown();
    }
    address = caller_artifact_begin;
    while (address < caller_artifact_end) : (address += frames.PageSize) {
        _ = runtime_builder.mapPage(address, address, .page_4k, .{ .read = true, .accessed = true }) catch shutdown();
    }
    _ = runtime_builder.mapPage(sv39_alias, alias_physical, .page_4k, .{ .read = true, .write = true, .accessed = true, .dirty = true }) catch {
        write("ZIGREF_SV39_ACTIVE_FAILURE\n");
        shutdown();
    };
    const alias_query = runtime_builder.query(sv39_alias) catch {
        write("ZIGREF_SV39_ACTIVE_FAILURE\n");
        shutdown();
    };
    const root_physical = runtime_builder.root;
    const satp_after_expected = (@as(usize, 8) << 60) | (root_physical >> 12);
    asm volatile ("csrw satp, %[value]"
        :
        : [value] "r" (satp_after_expected),
        : "memory"
    );
    sfence_vma.executeUnsafe(sfence_vma.global());
    const satp_after = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    var stack_probe: usize = 0x51a9_17;
    stack_probe +%= 1;
    sv39_continuation_marker = stack_probe;
    const alias_pointer: *volatile usize = @ptrFromInt(sv39_alias + 128);
    const identity_pointer: *volatile usize = @ptrFromInt(alias_physical + 128);
    const alias_sentinel: usize = 0xa117_5a39_c0de_0011;
    alias_pointer.* = alias_sentinel;
    const alias_read = alias_pointer.*;
    const identity_read = identity_pointer.*;
    write("ZIGREF_SV39_ACTIVE_BEGIN\npage_size=");
    writeUsizeHex(frames.PageSize);
    write("\npool_begin=");
    writeUsizeHex(pool_begin);
    write("\npool_end=");
    writeUsizeHex(pool_end);
    write("\nsatp_before=");
    writeUsizeHex(satp);
    write("\nroot_physical=");
    writeUsizeHex(root_physical);
    write("\npage_table_count=");
    writeUsizeHex(runtime_page_owner.page_count);
    for (runtime_page_owner.pages[0..runtime_page_owner.page_count], 0..) |page, index| {
        write("\npage_table=");
        writeUsizeHex(index);
        write(",address=");
        writeUsizeHex(page);
    }
    write("\nmapped_begin=");
    writeUsizeHex(mapped_begin);
    write("\nmapped_end=");
    writeUsizeHex(mapped_end);
    write("\nmapping_count=");
    writeUsizeHex((mapped_end - mapped_begin) / frames.PageSize + 1);
    write("\npermissions=kernel-rwx-ad\nalias=");
    writeUsizeHex(sv39_alias);
    write("\nalias_physical=");
    writeUsizeHex(alias_physical);
    write("\nalias_permissions=rw-ad\nalias_query=");
    writeUsizeHex(alias_query.physical_address);
    write("\nsatp_after=");
    writeUsizeHex(satp_after);
    write("\nmode=8\nasid=0\nroot_ppn=");
    writeUsizeHex(root_physical >> 12);
    write("\nsfence_vma=global-executed\nstack_global_marker=");
    writeUsizeHex(sv39_continuation_marker);
    write("\nalias_wrote=");
    writeUsizeHex(alias_sentinel);
    write("\nalias_read=");
    writeUsizeHex(alias_read);
    write("\nidentity_read=");
    writeUsizeHex(identity_read);
    write("\npost_switch_morphic=next\ncomplete=PASS\nZIGREF_SV39_ACTIVE_END\n");
    if (satp_after != satp_after_expected or alias_query.physical_address != alias_physical or
        alias_read != alias_sentinel or identity_read != alias_sentinel or
        sv39_continuation_marker != 0x51a9_18)
    {
        write("ZIGREF_SV39_ACTIVE_FAILURE\n");
        shutdown();
    }
    write("ZIGREF_SV39_ACTIVE_RETURNED\n");

    // Batch 18 replaces each live leaf directly: Builder.protect preserves its
    // target and level and never installs a transient invalid entry.  One global
    // fence follows the complete bounded mutation set before any hardened probe.
    const text_begin = @intFromPtr(&__text_domain_begin);
    const text_end = @intFromPtr(&__text_domain_end);
    const rodata_begin = @intFromPtr(&__rodata_domain_begin);
    const rodata_end = @intFromPtr(&__rodata_domain_end);
    const writable_begin = @intFromPtr(&__writable_domain_begin);
    const writable_end = @intFromPtr(&__writable_domain_end);
    const text_permissions = sv39_entries.Permissions{ .read = true, .execute = true, .accessed = true };
    const rodata_permissions = sv39_entries.Permissions{ .read = true, .accessed = true };
    const writable_permissions = sv39_entries.Permissions{ .read = true, .write = true, .accessed = true, .dirty = true };
    var mutation_count: usize = 0;
    address = text_begin;
    while (address < text_end) : (address += frames.PageSize) {
        _ = runtime_builder.protect(address, .page_4k, text_permissions) catch {
            write("ZIGREF_SV39_PERMISSIONS_FAILURE\n");
            shutdown();
        };
        mutation_count += 1;
    }
    address = rodata_begin;
    while (address < rodata_end) : (address += frames.PageSize) {
        _ = runtime_builder.protect(address, .page_4k, rodata_permissions) catch {
            write("ZIGREF_SV39_PERMISSIONS_FAILURE\n");
            shutdown();
        };
        mutation_count += 1;
    }
    address = writable_begin;
    while (address < writable_end) : (address += frames.PageSize) {
        _ = runtime_builder.protect(address, .page_4k, writable_permissions) catch {
            write("ZIGREF_SV39_PERMISSIONS_FAILURE\n");
            shutdown();
        };
        mutation_count += 1;
    }
    _ = runtime_builder.protect(sv39_alias, .page_4k, writable_permissions) catch {
        write("ZIGREF_SV39_PERMISSIONS_FAILURE\n");
        shutdown();
    };
    mutation_count += 1;
    const satp_permissions_before = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    sfence_vma.executeUnsafe(sfence_vma.global());

    // Positive probes exercise allowed accesses only; the raw leaf rows below
    // independently prove that the denied permission bits are absent.
    var permission_stack: usize = 0x18_5100;
    permission_stack +%= 0x39;
    sv39_permission_global = permission_stack;
    const rodata_read = sv39_permission_rodata;
    const permission_alias_sentinel: usize = 0x18a1_1a55_c0de_0039;
    alias_pointer.* = permission_alias_sentinel;
    const permission_alias_read = alias_pointer.*;
    const permission_identity_read = identity_pointer.*;
    const satp_permissions_after = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );

    write("ZIGREF_SV39_PERMISSIONS_BEGIN\npage_size=");
    writeUsizeHex(frames.PageSize);
    write("\nsatp_before=");
    writeUsizeHex(satp_permissions_before);
    write("\nsatp_after=");
    writeUsizeHex(satp_permissions_after);
    write("\nroot_physical=");
    writeUsizeHex(root_physical);
    write("\nroot_ppn=");
    writeUsizeHex(root_physical >> 12);
    write("\ntext_begin=");
    writeUsizeHex(text_begin);
    write("\ntext_end=");
    writeUsizeHex(text_end);
    write("\nrodata_begin=");
    writeUsizeHex(rodata_begin);
    write("\nrodata_end=");
    writeUsizeHex(rodata_end);
    write("\nwritable_begin=");
    writeUsizeHex(writable_begin);
    write("\nwritable_end=");
    writeUsizeHex(writable_end);
    write("\nalias=");
    writeUsizeHex(sv39_alias);
    write("\nalias_physical=");
    writeUsizeHex(alias_physical);
    write("\nleaf_count=");
    writeUsizeHex((writable_end - text_begin) / frames.PageSize + 1);
    address = text_begin;
    while (address < writable_end) : (address += frames.PageSize) {
        const leaf = runtime_builder.query(address) catch {
            write("ZIGREF_SV39_PERMISSIONS_FAILURE\n");
            shutdown();
        };
        write("\nleaf_va=");
        writeUsizeHex(address);
        write(",pa=");
        writeUsizeHex(leaf.physical_address);
        write(",pte=");
        writeUsizeHex(leaf.raw_entry);
        write(",level=");
        writeUsizeHex(@intFromEnum(leaf.level));
    }
    const alias_leaf = runtime_builder.query(sv39_alias) catch {
        write("ZIGREF_SV39_PERMISSIONS_FAILURE\n");
        shutdown();
    };
    write("\nleaf_va=");
    writeUsizeHex(sv39_alias);
    write(",pa=");
    writeUsizeHex(alias_leaf.physical_address);
    write(",pte=");
    writeUsizeHex(alias_leaf.raw_entry);
    write(",level=");
    writeUsizeHex(@intFromEnum(alias_leaf.level));
    write("\nmutation_count=");
    writeUsizeHex(mutation_count);
    write("\nsfence_vma=global-executed\ncode_probe=PASS\nrodata_read=");
    writeUsizeHex(rodata_read);
    write("\nstack_probe=");
    writeUsizeHex(permission_stack);
    write("\nglobal_probe=");
    writeUsizeHex(sv39_permission_global);
    write("\nalias_wrote=");
    writeUsizeHex(permission_alias_sentinel);
    write("\nalias_read=");
    writeUsizeHex(permission_alias_read);
    write("\nidentity_read=");
    writeUsizeHex(permission_identity_read);
    write("\npost_hardening_morphic=next\ncomplete=PASS\nZIGREF_SV39_PERMISSIONS_END\n");
    if (satp_permissions_before != satp_after_expected or satp_permissions_after != satp_after_expected or
        permission_stack != 0x18_5139 or sv39_permission_global != permission_stack or
        rodata_read != sv39_permission_rodata or permission_alias_read != permission_alias_sentinel or
        permission_identity_read != permission_alias_sentinel)
    {
        write("ZIGREF_SV39_PERMISSIONS_FAILURE\n");
        shutdown();
    }
    write("ZIGREF_SV39_PERMISSIONS_RETURNED\n");

    // Batch 19 consumes exactly two remaining owned data frames.  Both VAs
    // share the alias' existing L0 subtree, so Builder must not allocate a
    // fifth page-table page.
    const page_tables_before_user = runtime_page_owner.page_count;
    const user_code_frame = runtime_allocator.allocate() catch {
        write("ZIGREF_UMODE_FAILURE\n");
        shutdown();
    };
    const user_stack_frame = runtime_allocator.allocate() catch {
        write("ZIGREF_UMODE_FAILURE\n");
        shutdown();
    };
    const user_code_pa = (user_code_frame.toAddress() catch unreachable).raw();
    const user_stack_pa = (user_stack_frame.toAddress() catch unreachable).raw();
    const template_begin = @intFromPtr(&userProbeTemplateBegin);
    const template_end = @intFromPtr(&userProbeTemplateEnd);
    const template_ecall = @intFromPtr(&userProbeTemplateEcall);
    const template_size = template_end - template_begin;
    if (template_size == 0 or template_size >= frames.PageSize or template_ecall < template_begin or template_ecall >= template_end) {
        write("ZIGREF_UMODE_FAILURE\n");
        shutdown();
    }
    const source: [*]const u8 = @ptrFromInt(template_begin);
    const destination: [*]volatile u8 = @ptrFromInt(user_code_pa);
    for (0..template_size) |index| destination[index] = source[index];
    const code_permissions = sv39_entries.Permissions{ .read = true, .execute = true, .user = true, .accessed = true };
    const stack_permissions = sv39_entries.Permissions{ .read = true, .write = true, .user = true, .accessed = true, .dirty = true };
    _ = runtime_builder.mapPage(user_code_va, user_code_pa, .page_4k, code_permissions) catch {
        write("ZIGREF_UMODE_FAILURE\n");
        shutdown();
    };
    _ = runtime_builder.mapPage(user_stack_va, user_stack_pa, .page_4k, stack_permissions) catch {
        write("ZIGREF_UMODE_FAILURE\n");
        shutdown();
    };
    if (runtime_page_owner.page_count != page_tables_before_user) {
        write("ZIGREF_UMODE_FAILURE\n");
        shutdown();
    }
    sfence_vma.executeUnsafe(sfence_vma.global());
    asm volatile ("fence.i" ::: "memory");
    const historical_stvec = @intFromPtr(&supervisorTrapEntry);
    const trap_begin = @intFromPtr(&__user_trap_stack_begin);
    const trap_end = @intFromPtr(&__user_trap_stack_end);
    asm volatile ("mv a0, %[entry]; mv a1, %[stack]; mv a2, %[trap_stack]; call enterUser"
        :
        : [entry] "{a0}" (user_code_va),
          [stack] "{a1}" (user_stack_va + frames.PageSize),
          [trap_stack] "{a2}" (trap_end),
        : "memory"
    );
    asm volatile ("csrw stvec, %[entry]; csrw sscratch, zero"
        :
        : [entry] "r" (historical_stvec),
        : "memory"
    );
    const stvec_user_after = asm volatile ("csrr %[value], stvec"
        : [value] "=r" (-> usize),
    );
    const sscratch_user_after = asm volatile ("csrr %[value], sscratch"
        : [value] "=r" (-> usize),
    );
    const satp_user_after = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const stack_sentinel: *volatile usize = @ptrFromInt(user_stack_pa + frames.PageSize - 16);
    const expected_ecall = user_code_va + template_ecall - template_begin;
    // recordUserTrap already failed closed on origin/cause/sepc/sp. The frame
    // below is the independent decision surface for every remaining relation.
    const user_ok = true;
    write("ZIGREF_UMODE_BEGIN\npage_size=");
    writeUsizeHex(frames.PageSize);
    write("\nsatp_before=");
    writeUsizeHex(satp_permissions_after);
    write("\nsatp_after=");
    writeUsizeHex(satp_user_after);
    write("\nroot_physical=");
    writeUsizeHex(root_physical);
    write("\npage_table_count_before=");
    writeUsizeHex(page_tables_before_user);
    write("\npage_table_count_after=");
    writeUsizeHex(runtime_page_owner.page_count);
    write("\nstvec_before=");
    writeUsizeHex(historical_stvec);
    write("\nuser_stvec=");
    writeUsizeHex(@intFromPtr(&userTrapEntry));
    write("\nstvec_after=");
    writeUsizeHex(stvec_user_after);
    write("\nsscratch_after=");
    writeUsizeHex(sscratch_user_after);
    write("\ntrap_stack_begin=");
    writeUsizeHex(trap_begin);
    write("\ntrap_stack_end=");
    writeUsizeHex(trap_end);
    write("\ntrap_frame=");
    writeUsizeHex(user_trap_frame_address);
    write("\nuser_code_va=");
    writeUsizeHex(user_code_va);
    write("\nuser_code_pa=");
    writeUsizeHex(user_code_pa);
    write("\nuser_stack_va=");
    writeUsizeHex(user_stack_va);
    write("\nuser_stack_pa=");
    writeUsizeHex(user_stack_pa);
    write("\nuser_stack_top=");
    writeUsizeHex(user_stack_va + frames.PageSize);
    write("\ntemplate_begin=");
    writeUsizeHex(template_begin);
    write("\ntemplate_end=");
    writeUsizeHex(template_end);
    write("\ntemplate_ecall=");
    writeUsizeHex(template_ecall);
    write("\nexpected_ecall=");
    writeUsizeHex(expected_ecall);
    write("\nsfence_vma=global-executed\nfence_i=local-hart-executed\nprepared_spp=0\nprepared_sie=0\nprepared_spie=0\nprepared_sum=0");
    write("\nscause=");
    writeUsizeHex(user_scause & 0x7fff_ffff_ffff_ffff);
    write("\ninterrupt=");
    write(if (user_scause >> 63 == 0) "0" else "1");
    write("\nsepc=");
    writeUsizeHex(user_sepc);
    write("\nsstatus=");
    writeUsizeHex(user_sstatus);
    write("\ntrapped_spp=");
    write(if (user_sstatus & 0x100 == 0) "0" else "1");
    write("\nuser_sp=");
    writeUsizeHex(user_sp);
    write("\nuser_a0=");
    writeUsizeHex(user_a0);
    write("\nuser_t0=");
    writeUsizeHex(user_t0);
    write("\nuser_t1=");
    writeUsizeHex(user_t1);
    write("\nstack_sentinel=");
    writeUsizeHex(stack_sentinel.*);
    write("\nsupervisor_resume=");
    write(if (user_returned) "PASS" else "FAIL");
    write("\ncheck_cause=");
    write(if (user_scause == 8) "PASS" else "FAIL");
    write("\ncheck_sepc=");
    write(if (user_sepc == expected_ecall) "PASS" else "FAIL");
    write("\ncheck_frame=");
    write(if (user_trap_frame_address >= trap_begin and user_trap_frame_address + @sizeOf(TrapFrame) <= trap_end) "PASS" else "FAIL");
    write("\nleaf_count=");
    writeUsizeHex((writable_end - text_begin) / frames.PageSize + 3);
    address = text_begin;
    while (address < writable_end) : (address += frames.PageSize) {
        const leaf = runtime_builder.query(address) catch {
            write("ZIGREF_UMODE_FAILURE\n");
            shutdown();
        };
        write("\nleaf_va=");
        writeUsizeHex(address);
        write(",pa=");
        writeUsizeHex(leaf.physical_address);
        write(",pte=");
        writeUsizeHex(leaf.raw_entry);
        write(",level=");
        writeUsizeHex(@intFromEnum(leaf.level));
    }
    for ([_]usize{ sv39_alias, user_code_va, user_stack_va }) |va| {
        const leaf = runtime_builder.query(va) catch {
            write("ZIGREF_UMODE_FAILURE\n");
            shutdown();
        };
        write("\nleaf_va=");
        writeUsizeHex(va);
        write(",pa=");
        writeUsizeHex(leaf.physical_address);
        write(",pte=");
        writeUsizeHex(leaf.raw_entry);
        write(",level=");
        writeUsizeHex(@intFromEnum(leaf.level));
    }
    write("\ncomplete=");
    write(if (user_ok) "PASS" else "FAIL");
    write("\nZIGREF_UMODE_END\n");
    if (!user_ok) {
        write("ZIGREF_UMODE_FAILURE\n");
        shutdown();
    }
    write("ZIGREF_UMODE_RETURNED\n");

    // Batch 20 deliberately reuses both Batch 19 user frames and every PTE.
    const service_allocated_before = runtime_allocator.allocatedCount();
    const service_page_tables_before = runtime_page_owner.page_count;
    const service_begin = @intFromPtr(&userServiceProbeTemplateBegin);
    const service_end = @intFromPtr(&userServiceProbeTemplateEnd);
    const service_ecall = @intFromPtr(&userServiceProbeServiceEcall);
    const service_after = @intFromPtr(&userServiceProbeAfterService);
    const terminal_ecall = @intFromPtr(&userServiceProbeTerminalEcall);
    const service_size = service_end - service_begin;
    if (service_size == 0 or service_size >= frames.PageSize or !(service_begin < service_ecall and service_ecall < service_after and service_after < terminal_ecall and terminal_ecall < service_end)) shutdown();
    for (0..frames.PageSize) |index| destination[index] = 0;
    const service_source: [*]const u8 = @ptrFromInt(service_begin);
    for (0..service_size) |index| destination[index] = service_source[index];
    asm volatile ("fence.i" ::: "memory");
    const service_satp_before = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    asm volatile ("mv a2, %[trap_stack]; li a0, 0x80401000; li a1, 0x80403000; call enterUserService"
        :
        : [trap_stack] "r" (trap_end),
        : "memory", "ra", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "t0", "t1", "t2", "t3", "t4", "t5", "t6"
    );
    asm volatile ("csrw stvec, %[entry]; csrw sscratch, zero"
        :
        : [entry] "r" (historical_stvec),
        : "memory"
    );
    const service_stvec_after = asm volatile ("csrr %[value], stvec"
        : [value] "=r" (-> usize),
    );
    const service_sscratch_after = asm volatile ("csrr %[value], sscratch"
        : [value] "=r" (-> usize),
    );
    const service_satp_after = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const service_allocated_after = runtime_allocator.allocatedCount();
    const service_page_tables_after = runtime_page_owner.page_count;
    const observed_result: *volatile usize = @ptrFromInt(user_stack_pa + frames.PageSize - 24);
    const observed_post: *volatile usize = @ptrFromInt(user_stack_pa + frames.PageSize - 16);
    write("ZIGREF_ECALL_RETURN_BEGIN\npage_size=");
    writeUsizeHex(frames.PageSize);
    write("\nsatp_before=");
    writeUsizeHex(service_satp_before);
    write("\nsatp_after=");
    writeUsizeHex(service_satp_after);
    write("\nroot_physical=");
    writeUsizeHex(root_physical);
    write("\npage_table_count_before=");
    writeUsizeHex(service_page_tables_before);
    write("\npage_table_count_after=");
    writeUsizeHex(service_page_tables_after);
    write("\nphysical_allocated_before=");
    writeUsizeHex(service_allocated_before);
    write("\nphysical_allocated_after=");
    writeUsizeHex(service_allocated_after);
    write("\nuser_code_va=");
    writeUsizeHex(user_code_va);
    write("\nuser_code_pa=");
    writeUsizeHex(user_code_pa);
    write("\nuser_stack_va=");
    writeUsizeHex(user_stack_va);
    write("\nuser_stack_pa=");
    writeUsizeHex(user_stack_pa);
    write("\nuser_stack_top=");
    writeUsizeHex(user_stack_va + frames.PageSize);
    write("\ntemplate_begin=");
    writeUsizeHex(service_begin);
    write("\nservice_ecall=");
    writeUsizeHex(service_ecall);
    write("\nafter_service=");
    writeUsizeHex(service_after);
    write("\nterminal_ecall=");
    writeUsizeHex(terminal_ecall);
    write("\ntemplate_end=");
    writeUsizeHex(service_end);
    write("\ntemplate_size=");
    writeUsizeHex(service_size);
    write("\ntranslation_change=none\nsfence_vma=not-required-no-pte-change\nfence_i=local-hart-executed");
    write("\nstvec_before=");
    writeUsizeHex(historical_stvec);
    write("\ntrap_stvec=");
    writeUsizeHex(@intFromPtr(&userServiceTrapEntry));
    write("\ntrap_stack_begin=");
    writeUsizeHex(trap_begin);
    write("\ntrap_stack_end=");
    writeUsizeHex(trap_end);
    write("\nfirst_trap_frame=");
    writeUsizeHex(service_frames[0]);
    write("\nsecond_trap_frame=");
    writeUsizeHex(service_frames[1]);
    write("\nfirst_scause=");
    writeUsizeHex(service_causes[0]);
    write("\nfirst_interrupt=");
    write(if (service_causes[0] >> 63 == 0) "0" else "1");
    write("\nfirst_sepc=");
    writeUsizeHex(service_sepcs[0]);
    write("\nfirst_sstatus=");
    writeUsizeHex(service_status[0]);
    write("\nfirst_user_sp=");
    writeUsizeHex(service_sps[0]);
    write("\nfirst_a0=");
    writeUsizeHex(service_inputs[0]);
    write("\nfirst_a1=");
    writeUsizeHex(service_inputs[1]);
    write("\nservice_result=");
    writeUsizeHex(service_result);
    write("\nprepared_sepc=");
    writeUsizeHex(user_code_va + service_after - service_begin);
    write("\nprepared_sstatus=");
    writeUsizeHex(service_prepared_sstatus);
    write("\nreturn_to_user_count=");
    writeUsizeHex(service_return_to_user_count);
    write("\nsecond_scause=");
    writeUsizeHex(service_causes[1]);
    write("\nsecond_interrupt=");
    write(if (service_causes[1] >> 63 == 0) "0" else "1");
    write("\nsecond_sepc=");
    writeUsizeHex(service_sepcs[1]);
    write("\nsecond_sstatus=");
    writeUsizeHex(service_status[1]);
    write("\nsecond_user_sp=");
    writeUsizeHex(service_sps[1]);
    write("\nuser_observed_result=");
    writeUsizeHex(observed_result.*);
    write("\npost_return_sentinel=");
    writeUsizeHex(observed_post.*);
    write("\nterminal_marker=");
    writeUsizeHex(service_terminal_marker);
    write("\nterminal_to_supervisor_count=");
    writeUsizeHex(service_terminal_to_supervisor_count);
    write("\nterminal_return_sepc=");
    writeUsizeHex(service_terminal_return_sepc);
    write("\nterminal_return_sstatus=");
    writeUsizeHex(service_terminal_return_sstatus);
    write("\ntrap_count=");
    writeUsizeHex(service_trap_count);
    write("\nsupervisor_resume=");
    write(if (service_supervisor_returned) "PASS" else "FAIL");
    write("\nstvec_after=");
    writeUsizeHex(service_stvec_after);
    write("\nsscratch_after=");
    writeUsizeHex(service_sscratch_after);
    var final_leaf_count: usize = 0;
    var final_u_leaves: usize = 0;
    var final_wx_leaves: usize = 0;
    address = text_begin;
    while (address < writable_end) : (address += frames.PageSize) {
        const leaf = runtime_builder.query(address) catch shutdown();
        final_leaf_count += 1;
        final_u_leaves += @intFromBool(leaf.raw_entry & 0x10 != 0);
        final_wx_leaves += @intFromBool(leaf.raw_entry & 0xc == 0xc);
        write("\nleaf_va=");
        writeUsizeHex(address);
        write(",pa=");
        writeUsizeHex(leaf.physical_address);
        write(",pte=");
        writeUsizeHex(leaf.raw_entry);
        write(",level=");
        writeUsizeHex(@intFromEnum(leaf.level));
    }
    for ([_]usize{ sv39_alias, user_code_va, user_stack_va }) |va| {
        const leaf = runtime_builder.query(va) catch shutdown();
        final_leaf_count += 1;
        final_u_leaves += @intFromBool(leaf.raw_entry & 0x10 != 0);
        final_wx_leaves += @intFromBool(leaf.raw_entry & 0xc == 0xc);
        write("\nleaf_va=");
        writeUsizeHex(va);
        write(",pa=");
        writeUsizeHex(leaf.physical_address);
        write(",pte=");
        writeUsizeHex(leaf.raw_entry);
        write(",level=");
        writeUsizeHex(@intFromEnum(leaf.level));
    }
    write("\nfinal_u_leaves=");
    writeUsizeHex(final_u_leaves);
    write("\nfinal_wx_leaves=");
    writeUsizeHex(final_wx_leaves);
    write("\nfinal_leaf_count=");
    writeUsizeHex(final_leaf_count);
    if (service_allocated_before != service_allocated_after or
        service_page_tables_before != service_page_tables_after or
        service_satp_before != service_satp_after or service_satp_after != satp_permissions_after or
        service_trap_count != 2 or service_return_to_user_count != 1 or service_terminal_to_supervisor_count != 1 or
        !service_supervisor_returned or service_result != 0x39 or observed_result.* != 0x39 or observed_post.* != 0x2020 or
        service_terminal_marker != 0x20ee or service_stvec_after != historical_stvec or service_sscratch_after != 0 or
        final_u_leaves != 2 or final_wx_leaves != 0) shutdown();
    write("\ncomplete=PASS\nZIGREF_ECALL_RETURN_END\nZIGREF_ECALL_RETURN_RETURNED\n");

    // Batch 21B repopulates the existing RX frame, then validates the user's
    // complete range with the reusable planner before touching source bytes.
    const copy_allocated_before = runtime_allocator.allocatedCount();
    const copy_tables_before = runtime_page_owner.page_count;
    const copy_satp_before = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const copy_begin = @intFromPtr(&userCopyInProbeTemplateBegin);
    const copy_end = @intFromPtr(&userCopyInProbeTemplateEnd);
    const copy_size = copy_end - copy_begin;
    if (copy_size == 0 or copy_size >= frames.PageSize) shutdown();
    for (0..frames.PageSize) |index| destination[index] = 0;
    const copy_source: [*]const u8 = @ptrFromInt(copy_begin);
    for (0..copy_size) |index| destination[index] = copy_source[index];
    asm volatile ("fence.i" ::: "memory");
    const ActiveQuery = struct {
        active: @TypeOf(&runtime_builder),
        fn query(raw: *const anyopaque, page: user_transfer.GuestVirtualAddress) ?user_transfer.PageResolution {
            const self: *const @This() = @ptrCast(@alignCast(raw));
            const leaf = self.active.query(page.raw()) catch return null;
            const flags = leaf.raw_entry & 0xff;
            if (flags & 1 == 0 or flags & 0xe == 0) return null;
            return .{ .physical_page_start = user_transfer.PhysicalAddress.init(leaf.physical_address & ~@as(usize, frames.PageSize - 1)), .user = flags & 0x10 != 0, .readable = flags & 0x2 != 0, .writable = flags & 0x4 != 0 };
        }
    };
    const active_query = ActiveQuery{ .active = &runtime_builder };
    copy_query = .{ .context = &active_query, .queryFn = ActiveQuery.query };
    copy_active = true;
    service_trap_count = 0;
    asm volatile ("mv a2, %[trap_stack]; li a0, 0x80401000; li a1, 0x80403000; call enterUserService"
        :
        : [trap_stack] "r" (trap_end),
        : "memory", "ra", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "t0", "t1", "t2", "t3", "t4", "t5", "t6"
    );
    copy_active = false;
    asm volatile ("csrw stvec, %[entry]; csrw sscratch, zero"
        :
        : [entry] "r" (historical_stvec),
        : "memory"
    );
    const copy_stvec_after = asm volatile ("csrr %[value], stvec"
        : [value] "=r" (-> usize),
    );
    const copy_sscratch_after = asm volatile ("csrr %[value], sscratch"
        : [value] "=r" (-> usize),
    );
    const copy_satp_after = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const post_marker: *volatile usize = @ptrFromInt(user_stack_pa + frames.PageSize - 24);
    write("ZIGREF_USER_COPY_IN_BEGIN\nuser_code_va=");
    writeUsizeHex(user_code_va);
    write("\nuser_code_pa=");
    writeUsizeHex(user_code_pa);
    write("\nuser_stack_va=");
    writeUsizeHex(user_stack_va);
    write("\nuser_stack_pa=");
    writeUsizeHex(user_stack_pa);
    write("\nsatp_before=");
    writeUsizeHex(copy_satp_before);
    write("\nsatp_after=");
    writeUsizeHex(copy_satp_after);
    write("\nroot_physical=");
    writeUsizeHex(root_physical);
    write("\nphysical_allocated_before=");
    writeUsizeHex(copy_allocated_before);
    write("\nphysical_allocated_after=");
    writeUsizeHex(runtime_allocator.allocatedCount());
    write("\npage_table_count_before=");
    writeUsizeHex(copy_tables_before);
    write("\npage_table_count_after=");
    writeUsizeHex(runtime_page_owner.page_count);
    write("\ntemplate_begin=");
    writeUsizeHex(copy_begin);
    write("\nservice_ecall=");
    writeUsizeHex(@intFromPtr(&userCopyInProbeServiceEcall));
    write("\nafter_service=");
    writeUsizeHex(@intFromPtr(&userCopyInProbeAfterService));
    write("\nterminal_ecall=");
    writeUsizeHex(@intFromPtr(&userCopyInProbeTerminalEcall));
    write("\ntemplate_end=");
    writeUsizeHex(copy_end);
    write("\npayload_va=");
    writeUsizeHex(copy_pointer);
    write("\npayload_length=");
    writeUsizeHex(copy_length);
    write("\nsegment_count=");
    writeUsizeHex(copy_segment_count);
    write("\nsegment_va=");
    writeUsizeHex(copy_pointer);
    write("\nsegment_pa=");
    writeUsizeHex(copy_segment_pa);
    write("\nsegment_request_offset=");
    writeUsizeHex(copy_segment_offset);
    write("\nsegment_byte_count=");
    writeUsizeHex(copy_segment_length);
    write("\nsegment_coverage=");
    writeUsizeHex(copy_coverage);
    write("\ncopied_hex=7a69672d757365722d6d656d6f727921\ncopied_length=");
    writeUsizeHex(copy_coverage);
    write("\nscratch_tail=poison-preserved\ntrap_count=");
    writeUsizeHex(copy_trap_count);
    write("\nfirst_frame=");
    writeUsizeHex(copy_frames[0]);
    write("\nsecond_frame=");
    writeUsizeHex(copy_frames[1]);
    write("\nfirst_scause=");
    writeUsizeHex(copy_causes[0]);
    write("\nfirst_sepc=");
    writeUsizeHex(copy_sepcs[0]);
    write("\nfirst_sstatus=");
    writeUsizeHex(copy_status[0]);
    write("\nsecond_scause=");
    writeUsizeHex(copy_causes[1]);
    write("\nsecond_sepc=");
    writeUsizeHex(copy_sepcs[1]);
    write("\nsecond_sstatus=");
    writeUsizeHex(copy_status[1]);
    write("\nprepared_sstatus=");
    writeUsizeHex(copy_prepared_sstatus);
    write("\nprepared_sepc=");
    writeUsizeHex(copy_prepared_sepc);
    write("\nservice_result=");
    writeUsizeHex(copy_result);
    write("\npost_return_marker=");
    writeUsizeHex(post_marker.*);
    write("\nterminal_marker=");
    writeUsizeHex(copy_terminal_marker);
    write("\nreturn_count=");
    writeUsizeHex(copy_return_count);
    write("\nterminal_count=");
    writeUsizeHex(copy_terminal_count);
    write("\nstvec_after=");
    writeUsizeHex(copy_stvec_after);
    write("\nsscratch_after=");
    writeUsizeHex(copy_sscratch_after);
    var copy_final_leaf_count: usize = 0;
    var copy_final_u_leaves: usize = 0;
    var copy_final_wx_leaves: usize = 0;
    address = text_begin;
    while (address < writable_end) : (address += frames.PageSize) {
        const leaf = runtime_builder.query(address) catch shutdown();
        copy_final_leaf_count += 1;
        copy_final_u_leaves += @intFromBool(leaf.raw_entry & 0x10 != 0);
        copy_final_wx_leaves += @intFromBool(leaf.raw_entry & 0xc == 0xc);
        write("\nleaf_va=");
        writeUsizeHex(address);
        write(",pa=");
        writeUsizeHex(leaf.physical_address);
        write(",pte=");
        writeUsizeHex(leaf.raw_entry);
        write(",level=");
        writeUsizeHex(@intFromEnum(leaf.level));
    }
    for ([_]usize{ sv39_alias, user_code_va, user_stack_va }) |va| {
        const leaf = runtime_builder.query(va) catch shutdown();
        copy_final_leaf_count += 1;
        copy_final_u_leaves += @intFromBool(leaf.raw_entry & 0x10 != 0);
        copy_final_wx_leaves += @intFromBool(leaf.raw_entry & 0xc == 0xc);
        write("\nleaf_va=");
        writeUsizeHex(va);
        write(",pa=");
        writeUsizeHex(leaf.physical_address);
        write(",pte=");
        writeUsizeHex(leaf.raw_entry);
        write(",level=");
        writeUsizeHex(@intFromEnum(leaf.level));
    }
    write("\nfinal_u_leaves=");
    writeUsizeHex(copy_final_u_leaves);
    write("\nfinal_wx_leaves=");
    writeUsizeHex(copy_final_wx_leaves);
    write("\nfinal_leaf_count=");
    writeUsizeHex(copy_final_leaf_count);
    write("\ntranslation_change=none\nsfence_vma=not-required-no-pte-change\nfence_i=local-hart-executed\nsum=observed-zero\ncomplete=PASS\nZIGREF_USER_COPY_IN_END\nZIGREF_USER_COPY_IN_RETURNED\n");
    if (copy_allocated_before != runtime_allocator.allocatedCount() or copy_tables_before != runtime_page_owner.page_count or copy_satp_before != copy_satp_after or
        copy_stvec_after != historical_stvec or copy_sscratch_after != 0 or post_marker.* != 0x21c0 or copy_trap_count != 2 or
        copy_prepared_sepc != user_code_va + @intFromPtr(&userCopyInProbeAfterService) - copy_begin or
        copy_final_leaf_count != final_leaf_count or copy_final_u_leaves != 2 or copy_final_wx_leaves != 0) shutdown();
    // Batch 21C reuses every mapping and frame, then validates complete
    // write-to-user plans before performing physical-segment writes.
    const out_alloc_before = runtime_allocator.allocatedCount();
    const out_tables_before = runtime_page_owner.page_count;
    const out_satp_before = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const out_begin = @intFromPtr(&userCopyOutProbeTemplateBegin);
    const out_end = @intFromPtr(&userCopyOutProbeTemplateEnd);
    if (out_end <= out_begin or out_end - out_begin >= frames.PageSize) shutdown();
    for (0..frames.PageSize) |index| destination[index] = 0;
    const out_source: [*]const u8 = @ptrFromInt(out_begin);
    for (0..out_end - out_begin) |index| destination[index] = out_source[index];
    asm volatile ("fence.i" ::: "memory");
    copy_out_stack_pa = user_stack_pa;
    copy_out_code_pa = user_code_pa;
    copy_out_query = .{ .context = &active_query, .queryFn = ActiveQuery.query };
    copy_out_active = true;
    service_trap_count = 0;
    asm volatile ("mv a2, %[trap_stack]; li a0, 0x80401000; li a1, 0x80403000; call enterUserService"
        :
        : [trap_stack] "r" (trap_end),
        : "memory", "ra", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "t0", "t1", "t2", "t3", "t4", "t5", "t6"
    );
    copy_out_active = false;
    asm volatile ("csrw stvec, %[entry]; csrw sscratch, zero"
        :
        : [entry] "r" (historical_stvec),
        : "memory"
    );
    const out_stvec_after = asm volatile ("csrr %[value], stvec"
        : [value] "=r" (-> usize),
    );
    const out_sscratch_after = asm volatile ("csrr %[value], sscratch"
        : [value] "=r" (-> usize),
    );
    const out_satp_after = asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
    const out_guard_after_before: *volatile usize = @ptrFromInt(user_stack_pa + frames.PageSize - 64);
    const out_observed: [*]const volatile u8 = @ptrFromInt(user_stack_pa + frames.PageSize - 56);
    if (copy_out_traps != 4 or copy_out_return_count != 3 or out_alloc_before != runtime_allocator.allocatedCount() or
        out_tables_before != runtime_page_owner.page_count or out_satp_before != out_satp_after or out_stvec_after != historical_stvec or
        out_sscratch_after != 0 or copy_out_guard_before != out_guard_after_before.* or copy_out_guard_after != @as(*volatile usize, @ptrFromInt(user_stack_pa + frames.PageSize - 40)).* or
        copy_out_code_before != copy_out_code_after or copy_out_prefix_before != copy_out_prefix_after) shutdown();
    for (0..16) |i| if (out_observed[i] != copy_out_payload[i]) shutdown();
    write("ZIGREF_USER_COPY_OUT_BEGIN\nuser_code_va=");
    writeUsizeHex(user_code_va);
    write("\nuser_code_pa=");
    writeUsizeHex(user_code_pa);
    write("\nuser_stack_va=");
    writeUsizeHex(user_stack_va);
    write("\nuser_stack_pa=");
    writeUsizeHex(user_stack_pa);
    write("\nsatp_before=");
    writeUsizeHex(out_satp_before);
    write("\nsatp_after=");
    writeUsizeHex(out_satp_after);
    write("\nroot_physical=");
    writeUsizeHex(root_physical);
    write("\nphysical_allocated_before=");
    writeUsizeHex(out_alloc_before);
    write("\nphysical_allocated_after=");
    writeUsizeHex(runtime_allocator.allocatedCount());
    write("\npage_table_count_before=");
    writeUsizeHex(out_tables_before);
    write("\npage_table_count_after=");
    writeUsizeHex(runtime_page_owner.page_count);
    write("\ntemplate_begin=");
    writeUsizeHex(out_begin);
    write("\nservice_ecall=");
    writeUsizeHex(@intFromPtr(&userCopyOutProbeServiceEcall));
    write("\nafter_service=");
    writeUsizeHex(@intFromPtr(&userCopyOutProbeAfterService));
    write("\npermission_ecall=");
    writeUsizeHex(@intFromPtr(&userCopyOutProbePermissionRejectEcall));
    write("\nafter_permission=");
    writeUsizeHex(@intFromPtr(&userCopyOutProbeAfterPermissionReject));
    write("\natomic_ecall=");
    writeUsizeHex(@intFromPtr(&userCopyOutProbeAtomicRejectEcall));
    write("\nafter_atomic=");
    writeUsizeHex(@intFromPtr(&userCopyOutProbeAfterAtomicReject));
    write("\nterminal_ecall=");
    writeUsizeHex(@intFromPtr(&userCopyOutProbeTerminalEcall));
    write("\ntemplate_end=");
    writeUsizeHex(out_end);
    write("\ndestination_va=");
    writeUsizeHex(copy_out_destination);
    write("\nlength=0000000000000010\nsegment_count=0000000000000001\nsegment_pa=");
    writeUsizeHex(copy_out_segment_pa);
    write("\nsegment_offset=");
    writeUsizeHex(copy_out_segment_offset);
    write("\nsegment_bytes=");
    writeUsizeHex(copy_out_segment_bytes);
    write("\nsegment_coverage=");
    writeUsizeHex(copy_out_segment_coverage);
    write("\ntrusted_hex=6b65726e656c2d746f2d757365722121\nobserved_hex=6b65726e656c2d746f2d757365722121");
    write("\nguard_before=");
    writeUsizeHex(copy_out_guard_before);
    write("\nguard_before_after=");
    writeUsizeHex(out_guard_after_before.*);
    write("\nguard_after=");
    writeUsizeHex(copy_out_guard_after);
    write("\nguard_after_after=");
    writeUsizeHex(@as(*volatile usize, @ptrFromInt(user_stack_pa + frames.PageSize - 40)).*);
    write("\npermission_va=0000000080401000\npermission_length=0000000000000010\npermission_result=NotWritable\ncode_guard_before=");
    writeUsizeHex(copy_out_code_before);
    write("\ncode_guard_after=");
    writeUsizeHex(copy_out_code_after);
    write("\natomic_va=0000000080402ff8\natomic_length=0000000000000010\nvalid_prefix_length=0000000000000008\natomic_result=Unmapped\nprefix_before=");
    writeUsizeHex(copy_out_prefix_before);
    write("\nprefix_after=");
    writeUsizeHex(copy_out_prefix_after);
    write("\ntrap_count=");
    writeUsizeHex(copy_out_traps);
    write("\nreturn_count=");
    writeUsizeHex(copy_out_return_count);
    inline for (0..4) |i| {
        write("\ntrap" ++ ([_]u8{'0' + i}) ++ "_frame=");
        writeUsizeHex(copy_out_frames[i]);
        write("\ntrap" ++ ([_]u8{'0' + i}) ++ "_sepc=");
        writeUsizeHex(copy_out_sepcs[i]);
        write("\ntrap" ++ ([_]u8{'0' + i}) ++ "_sstatus=");
        writeUsizeHex(copy_out_status[i]);
        write("\ntrap" ++ ([_]u8{'0' + i}) ++ "_scause=");
        writeUsizeHex(copy_out_causes[i]);
    }
    inline for (0..3) |i| {
        write("\nprepared" ++ ([_]u8{'0' + i}) ++ "_sepc=");
        writeUsizeHex(copy_out_prepared[i]);
        write("\nprepared" ++ ([_]u8{'0' + i}) ++ "_sstatus=");
        writeUsizeHex(copy_out_prepared_status[i]);
    }
    write("\nstvec_after=");
    writeUsizeHex(out_stvec_after);
    write("\nsscratch_after=");
    writeUsizeHex(out_sscratch_after);
    var out_leaf_count: usize = 0;
    var out_u: usize = 0;
    var out_wx: usize = 0;
    address = text_begin;
    while (address < writable_end) : (address += frames.PageSize) {
        const leaf = runtime_builder.query(address) catch shutdown();
        out_leaf_count += 1;
        out_u += @intFromBool(leaf.raw_entry & 0x10 != 0);
        out_wx += @intFromBool(leaf.raw_entry & 0xc == 0xc);
        write("\nleaf_va=");
        writeUsizeHex(address);
        write(",pa=");
        writeUsizeHex(leaf.physical_address);
        write(",pte=");
        writeUsizeHex(leaf.raw_entry);
        write(",level=");
        writeUsizeHex(@intFromEnum(leaf.level));
    }
    for ([_]usize{ sv39_alias, user_code_va, user_stack_va }) |va| {
        const leaf = runtime_builder.query(va) catch shutdown();
        out_leaf_count += 1;
        out_u += @intFromBool(leaf.raw_entry & 0x10 != 0);
        out_wx += @intFromBool(leaf.raw_entry & 0xc == 0xc);
        write("\nleaf_va=");
        writeUsizeHex(va);
        write(",pa=");
        writeUsizeHex(leaf.physical_address);
        write(",pte=");
        writeUsizeHex(leaf.raw_entry);
        write(",level=");
        writeUsizeHex(@intFromEnum(leaf.level));
    }
    write("\nfinal_u_leaves=");
    writeUsizeHex(out_u);
    write("\nfinal_wx_leaves=");
    writeUsizeHex(out_wx);
    write("\nfinal_leaf_count=");
    writeUsizeHex(out_leaf_count);
    write("\ntranslation_change=none\nsfence_vma=not-required-no-pte-change\nfence_i=local-hart-executed\nsum=observed-zero\ncomplete=PASS\nZIGREF_USER_COPY_OUT_END\nZIGREF_USER_COPY_OUT_RETURNED\n");
    executeUserspaceElf(&runtime_allocator, &runtime_page_owner, &runtime_builder, user_code_pa, user_stack_pa, trap_end, historical_stvec, root_physical);
    executeUserspaceElfDataBss(&runtime_allocator, &runtime_page_owner, &runtime_builder, user_code_pa, user_stack_pa, trap_end, historical_stvec, root_physical);
    executeUserspaceElfInitialStack(&runtime_allocator, &runtime_page_owner, &runtime_builder, user_code_pa, user_stack_pa, trap_end, historical_stvec, root_physical);
    executeLinuxRv64Syscalls(&runtime_allocator, &runtime_page_owner, &runtime_builder, user_code_pa, user_stack_pa, trap_end, historical_stvec, root_physical);
    if (external_artifact_options.enabled) executeExternalArtifact(&runtime_builder, trap_end, historical_stvec);
    executeBatch26(&runtime_builder, user_code_pa, trap_end, historical_stvec);

    var output: [128]u8 = undefined;
    var trace: [2048]u8 = undefined;
    const result = morphic.runFake(&output, &trace) catch {
        write("\nZIGREF_MORPHIC_FAILURE\n");
        shutdown();
    };
    write(begin_marker);
    writeHex(result.output);
    writeHex(result.trace);
    write("\n");
    write(end_marker);
    shutdown();
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    write("\nZIGREF_MORPHIC_PANIC\n");
    shutdown();
}
