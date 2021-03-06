const std = @import("std");
const Sdk = @import(".gyro\\SDL.zig-MasterQ32-github.com-360e5ea1\\pkg\\Sdk.zig");
const pkgs = @import("deps.zig").pkgs;

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zig-snake-ai", "src/main.zig");

    const sdk = Sdk.init(b);
    exe.setTarget(target);
    sdk.link(exe, .dynamic);
    exe.addPackage(sdk.getWrapperPackage("sdl2")); // this links libc
    exe.addPackage(pkgs.clap);
    exe.addPackage(pkgs.zgame_clock);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
