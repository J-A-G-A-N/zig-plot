const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const download_cmd = downloadFiles(b.allocator) catch unreachable;
    var download_step = b.addSystemCommand(download_cmd);
    download_step.step.name = "download_stb_if_missing";

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib_mod.addIncludePath(b.path("deps/"));
    lib_mod.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
    lib_mod.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2/freetype/" });
    lib_mod.linkSystemLibrary("freetype", .{});
    lib_mod.addCSourceFile(.{ .file = b.path("deps/stb_truetype.c"), .flags = &[_][]const u8{"-O3"} });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe_mod.addImport("zig_plot", lib_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zig_plot",
        .root_module = lib_mod,
    });
    lib.step.dependOn(&download_step.step);
    const no_lib = b.option(bool, "no-lib", "skip emitting library") orelse false;
    if (no_lib) {
        b.getInstallStep().dependOn(&lib.step);
    } else b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zig_plot",
        .root_module = exe_mod,
    });

    const no_bin = b.option(bool, "no-bin", "skip emitting library") orelse false;
    if (no_bin) {
        b.getInstallStep().dependOn(&exe.step);
    } else b.installArtifact(exe);

    const no_llvm = b.option(bool, "no-llvm", "Don't use llvm") orelse false;
    if (no_llvm) {
        exe.use_llvm = false;
        lib.use_llvm = false;
    }
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");

    run_step.dependOn(&run_cmd.step);

    const example_name = b.option([]const u8, "example", "Build the given example ");
    //const build_all_examples = b.option(bool, "examples", "Build all examples");

    if (example_name) |name| {
        buildExample(b, name, lib_mod, target, optimize);
    }
}

fn buildExample(
    b: *std.Build,
    name: []const u8,
    lib_mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const example_path = b.fmt("examples/{s}.zig", .{name});
    const example_mod = b.createModule(.{
        .root_source_file = b.path(example_path),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    example_mod.addImport("zig_plot", lib_mod);

    const example_exe = b.addExecutable(.{
        .name = name,
        .root_module = example_mod,
    });
    b.installArtifact(example_exe);

    const run_example_cmd = b.addRunArtifact(example_exe);
    run_example_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_example_cmd.addArgs(args);
    }
    const run_example_step = b.step("run-example", "Run the specified example");
    run_example_step.dependOn(&run_example_cmd.step);
}

fn downloadStbImageWrite() []const []const u8 {
    const cwd = std.fs.cwd();
    const url = "https://raw.githubusercontent.com/nothings/stb/refs/heads/master/stb_image_write.h";
    const path = "deps/stb_image_write.h";
    // Check if file exists by trying to access it
    cwd.access(path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            // File doesn't exist, return download command
            return &[_][]const u8{
                "curl",
                "-L",
                url,
                "-o",
                path,
            };
        },
        else => {
            // Other error, assume file exists or is accessible
            return &[_][]const u8{"true"};
        },
    };
    // File exists and is accessible
    return &[_][]const u8{"true"};
}

const FileDownload = struct {
    url: []const u8,
    path: []const u8,
};

pub fn downloadFiles(allocator: std.mem.Allocator) ![][]const u8 {
    var commands = std.ArrayList([]const u8).init(allocator);

    const files = [_]FileDownload{
        .{ .url = "https://raw.githubusercontent.com/nothings/stb/refs/heads/master/stb_image_write.h", .path = "deps/stb_image_write.h" },
        .{ .url = "https://raw.githubusercontent.com/nothings/stb/refs/heads/master/stb_truetype.h", .path = "deps/stb_truetype.h" },
    };

    const cwd = std.fs.cwd();
    var any_missing = false;

    for (files) |file| {
        if (cwd.access(file.path, .{}) catch |err| err == error.FileNotFound) {
            any_missing = true;
            try commands.append("curl");
            try commands.append("-sSL");
            try commands.append(file.url);
            try commands.append("-o");
            try commands.append(file.path);
        }
    }

    if (!any_missing) {
        try commands.append("true");
    }

    return commands.toOwnedSlice();
}
