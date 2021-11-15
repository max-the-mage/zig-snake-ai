const std = @import("std");
const sdl = @import("sdl2");
const clap = @import("clap");
const adma = @import("adma");

const clock = @import("zgame_clock");
const Time = clock.Time;

pub const abs = std.math.absInt;
pub const divC = std.math.divCeil;
pub const divF = std.math.divFloor;
pub const divT = std.math.divTrunc;

const game = @import("game.zig");
const actor = @import("actor.zig");
const Actor = actor.Actor;

const win = game.win;
const arena = game.arena;
const Pos = game.Pos;
const Size = game.Size;
const Dir = game.Dir;
const Snake = game.Snake;
const rect = game.rect;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    const adma_ref = adma.AdmaAllocator.init();
    defer adma_ref.deinit();

    const ac = &adma_ref.allocator;

    const params = comptime [_]clap.Param(clap.Help){
        try clap.parseParam("-h, --help Display this and exit"),
        try clap.parseParam("-s, --size <NUM> Snake board size"),
        try clap.parseParam("-p, --paths Enable path rendering"),
        try clap.parseParam("-w, --wireframe Render snake body outlines"),
        try clap.parseParam("-b, --benchmark <NUM> Do render free benchmarking based on # of iterations"),
        try clap.parseParam("-f, --fast Disable vsync to run as fast as possible"),
        try clap.parseParam("-i, --interval <NUM> Interval of fps/benchmark messages in seconds"),
    };

    var args = try clap.parse(clap.Help, &params, .{});
    defer args.deinit();

    if (args.flag("--help")) {
        try clap.help(std.io.getStdErr().writer(), &params);
        std.os.exit(0);
    }

    arena.render_path = args.flag("--paths");
    arena.wireframe = args.flag("--wireframe");

    arena.benchmark = try std.fmt.parseUnsigned(
        usize, args.option("--benchmark") orelse "0", 10 
    );

    const interval = try std.fmt.parseFloat(f64, args.option("--interval") orelse "1.0");

    const size = try std.fmt.parseUnsigned(u32, args.option("--size") orelse "20", 10);
    arena.w = size;
    arena.h = size;
    arena.size = arena.w*arena.h;
    arena.cell_size = .{
        .w=@divFloor(win.w, @intCast(i32, arena.w)),
        .h=@divFloor(win.h, @intCast(i32, arena.h)),
    };

    arena.grid = try ac.alloc(arena.State, size*size);
    defer ac.free(arena.grid);

    var renderer: sdl.Renderer = undefined;
    var window: sdl.Window = undefined;
    try sdl.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer sdl.quit();
    
    defer if (arena.benchmark == 0) {
        renderer.destroy();
        window.destroy();
    };

    if (arena.benchmark == 0) {

        window = try sdl.createWindow(
            "snake",
            .{ .centered = {} }, .{ .centered = {} },
            win.w, win.h,
            .{ .shown = true },
        );
        
        renderer = try sdl.createRenderer(
            window, null, 
            .{ .accelerated = true, .present_vsync=!args.flag("--fast") }
        );
        try renderer.setDrawBlendMode(sdl.c.SDL_BLENDMODE_BLEND);
    }

    arena.rand = &std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())).random();

    arena.snake.body = std.ArrayList(Pos).init(ac);
    var snake = &arena.snake;
    
    defer snake.body.deinit();
    try snake.body.append(.{.x=0, .y=0});

    for (snake.body.items) |pos| {
        (try arena.getCell(pos.x, pos.y)).* = .snake;
    }

    var phc = try actor.PerturbedHC.init(ac);
    defer phc.deinit(ac);



    arena.newApple();

    var frame: usize = 0;
    var steps: usize = 0;
    var total_steps: usize = 0;
    var iterations: usize = 0;

    var timer = try std.time.Timer.start();
    var fps_timer = try std.time.Timer.start();

    var time = Time{};
    time.fixed_time = @floatToInt(u64, interval*@intToFloat(f64, std.time.ns_per_s));


    mainLoop: while (true) {
        if (arena.benchmark == 0) {
            while (sdl.pollEvent()) |ev| {
                switch (ev) {
                    .quit => break :mainLoop,
                    else => {},
                }
            }
        }

        if (@mod(frame, 1) == 0) {
            
            try snake.move(phc.interface().dir(snake.body.items[0]));
            steps += 1;
            total_steps += 1;

            if (snake.body.items.len == arena.size) {
                const cur_lap = fps_timer.lap();
                iterations += 1;

                if (arena.benchmark == 0) break :mainLoop;

                time.advance_frame(cur_lap);
                if (time.step_fixed_update()) 
                    std.log.err("run: {}, steps: {} time: {d:.7}s steps/apple: {d:.2}", .{
                        iterations, steps, 
                        @intToFloat(f64, cur_lap)/@intToFloat(f64, std.time.ns_per_s),
                        @intToFloat(f32, steps+1)/@intToFloat(f32, arena.size),
                    });
                if (iterations == arena.benchmark) break :mainLoop;

                steps = 0;
                // used instead of shrinkAndFree because:
                // adma crashes when trying to shrink bucket sizes
                // no real reason to free the snake body anyway, since it'll juts be reused anyway
                snake.body.shrinkRetainingCapacity(1); 
                snake.body.items[0] = Pos{.x=0, .y=0};
            }
        }
        frame += 1;

        if (arena.benchmark == 0) {
            try renderer.setColorRGB(0, 0, 0);
            try renderer.clear();
            
            try arena.draw(&renderer);
            try snake.draw(&renderer, &phc.interface());

            renderer.present();

            time.advance_frame(fps_timer.lap());

            if (time.step_fixed_update()) {
                std.log.err("fps: {d:.2}", .{@intToFloat(f64, std.time.ns_per_s)/@intToFloat(f64, time.delta_time)});
            }
        }
    }

    const t = @intToFloat(f64, timer.read())/@intToFloat(f64, std.time.ns_per_s);
    std.log.err("summary\n\ttime: {d:.4}s\n\titerations: {}\n\taverage steps: {d:.2}\n\tboard size: {}x{}\n\tcycles/s : {d:.0}", .{
        t,iterations, @intToFloat(f64, total_steps)/@intToFloat(f64, iterations),
        arena.w, arena.h, @intToFloat(f64, total_steps)/t,
    });
}