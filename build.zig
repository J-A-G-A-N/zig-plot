const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var download_step = b.addSystemCommand(getDownloadCommand());
    download_step.step.name = "download_stb_if_missing";

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("zig_plot_lib", lib_mod);
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zig_plot",
        .root_module = lib_mod,
    });

    lib.step.dependOn(&download_step.step);
    lib.addIncludePath(b.path("deps/"));

    const no_lib = b.option(bool, "no-lib", "skip emitting library") orelse false;

    if (no_lib) {
        b.getInstallStep().dependOn(&lib.step);
    } else b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zig_plot",
        .root_module = exe_mod,
    });
    exe.linkLibC();

    const no_bin = b.option(bool, "no-bin", "skip emiting binary") orelse false;
    if (no_bin) {
        b.getInstallStep().dependOn(&exe.step);
    } else b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");

    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn getDownloadCommand() []const []const u8 {
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
