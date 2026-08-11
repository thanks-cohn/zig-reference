const filesystem = @import("bounded-filesystem");
comptime { _ = filesystem.FileSystem(65537, 8, 8); }
