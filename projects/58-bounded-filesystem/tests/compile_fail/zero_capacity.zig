const filesystem = @import("bounded-filesystem");
comptime {
    _ = filesystem.FileSystem(0, 8, 8);
}
