const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    build_native(b, target, optimize);
}

fn build_native(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const dep_raylib = b.dependency(
        "raylib_zig",
        .{
            .target = target,
            .optimize = optimize,
        },
    );
    const raylib = dep_raylib.module("raylib");
    const raylib_artifact = dep_raylib.artifact("raylib");

    const mod_exe = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_name = b.option(
        []const u8,
        "exe_name",
        "Name of the executable",
    ) orelse "bitfont";

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_module = mod_exe,
    });
    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);

    // Add linux system paths
    if (builtin.os.tag == .linux) {
        const triple = builtin.target.linuxTriple(b.allocator) catch unreachable;
        const include_path = "/usr/include";
        const triple_path = b.fmt("/usr/lib/{s}", .{triple});
        raylib_artifact.addLibraryPath(.{ .src_path = .{
            .owner = b,
            .sub_path = triple_path,
        } });
        raylib_artifact.addSystemIncludePath(.{ .src_path = .{
            .owner = b,
            .sub_path = include_path,
        } });
        exe.addLibraryPath(.{ .src_path = .{
            .owner = b,
            .sub_path = triple_path,
        } });
        exe.addSystemIncludePath(.{ .src_path = .{
            .owner = b,
            .sub_path = include_path,
        } });
    }

    // Explicitly link system paths when target is specified
    // NOTE: system paths must be explicitly linked in cross-compile mode
    switch (target.result.os.tag) {
        .macos => {
            // Include xcode_frameworks for cross compilation
            if (b.lazyDependency("macos_sdk", .{})) |dep| {
                exe.addSystemFrameworkPath(dep.path("Frameworks"));
                exe.addSystemIncludePath(dep.path("include"));
                exe.addLibraryPath(dep.path("lib"));
            }
        },
        .linux => {
            raylib_artifact.linkSystemLibrary("GLX");
            raylib_artifact.linkSystemLibrary("X11");
            raylib_artifact.linkSystemLibrary("Xcursor");
            raylib_artifact.linkSystemLibrary("Xext");
            raylib_artifact.linkSystemLibrary("Xfixes");
            raylib_artifact.linkSystemLibrary("Xi");
            raylib_artifact.linkSystemLibrary("Xinerama");
            raylib_artifact.linkSystemLibrary("Xrandr");
            raylib_artifact.linkSystemLibrary("Xrender");
            raylib_artifact.linkSystemLibrary("EGL");
            raylib_artifact.linkSystemLibrary("wayland-client");
            raylib_artifact.linkSystemLibrary("xkbcommon");
            exe.linkSystemLibrary("GLX");
            exe.linkSystemLibrary("X11");
            exe.linkSystemLibrary("Xcursor");
            exe.linkSystemLibrary("Xext");
            exe.linkSystemLibrary("Xfixes");
            exe.linkSystemLibrary("Xi");
            exe.linkSystemLibrary("Xinerama");
            exe.linkSystemLibrary("Xrandr");
            exe.linkSystemLibrary("Xrender");
            exe.linkSystemLibrary("EGL");
            exe.linkSystemLibrary("wayland-client");
            exe.linkSystemLibrary("xkbcommon");
        },
        else => {},
    }

    // Embed asset files into the output binary
    add_assets(b, exe, target, optimize) catch |err| {
        std.log.err("Problem adding assets: {!}", .{err});
    };

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run bitfont compiled natively");
    run_step.dependOn(&run_cmd.step);
}

/// Add all files within the `src/assets` folder into the executable binary
fn add_assets(b: *std.Build, exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !void {
    var options = b.addOptions();
    var files = std.ArrayList([]const u8).init(b.allocator);
    defer files.deinit();

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fs.cwd().realpath("src/assets", buf[0..]);

    var dir = try std.fs.openDirAbsolute(path, .{
        .iterate = true,
    });
    var dir_iter = dir.iterate();
    while (try dir_iter.next()) |file| {
        if (file.kind != .file) {
            continue;
        }
        try files.append(b.dupe(file.name));
    }

    options.addOption([]const []const u8, "files", files.items);
    exe.step.dependOn(&options.step);

    const assets = b.addModule("assets", .{
        .root_source_file = options.getOutput(),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("assets", assets);
}
