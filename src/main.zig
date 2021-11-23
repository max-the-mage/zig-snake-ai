const std = @import("std");
const abs = std.math.absInt;
const divC = std.math.divCeil;
const divF = std.math.divFloor;
const divT = std.math.divTrunc;

const DefaultPrng = std.rand.DefaultPrng;
const mts = std.time.milliTimestamp;

const ascii = std.ascii;
const meta = std.meta;

const declInf = meta.declarationInfo;

const sdl = @import("sdl2");
const clap = @import("clap");
const adma = @import("adma");

const clock = @import("zgame_clock");
const Time = clock.Time;

const g = @import("game.zig");
const actor = @import("actor.zig");
const Actor = actor.Actor;

const win = g.win;
const Pos = g.Pos;
const Size = g.Size;
const Dir = g.Dir;
const Snake = g.Snake;
const Game = g.Game;
const rect = g.rect;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    const adma_ref = adma.AdmaAllocator.init();
    defer adma_ref.deinit();

    const ac = &adma_ref.allocator;

    const params = comptime [_]clap.Param(clap.Help){
        try clap.parseParam("-h, --help Display this and exit"),
        try clap.parseParam("-a, --actor <STR> Chose an actor,"),
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
        try _write_types();
        std.os.exit(0);
    }

    const benchmark = try std.fmt.parseUnsigned(
        usize, args.option("--benchmark") orelse "0", 10 
    );

    const interval = try std.fmt.parseFloat(f64, args.option("--interval") orelse "1.0");

    const size = try std.fmt.parseUnsigned(i32, args.option("--size") orelse "20", 10);
    var game = try Game.init(
        size, ac, &DefaultPrng.init(@intCast(u64, mts())).random(), 
        Game.Config{
            .draw_wireframe = args.flag("--wireframe"),
            .draw_ai_data = args.flag("--paths"),
        },
    );
    defer game.deinit();

    var renderer: sdl.Renderer = undefined;
    var window: sdl.Window = undefined;
    try sdl.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer sdl.quit();
    
    defer if (benchmark == 0) {
        renderer.destroy();
        window.destroy();
    };

    if (benchmark == 0) {

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

    const act_str = args.option("--actor");

    //var actor_tag: actor.ActorTag = undefined;
    var actor_type: actor.ActorType = undefined;

    if (act_str) |ac_real| {
        inline for (std.meta.fields(actor.ActorType)) |field| {
            if (
                ascii.eqlIgnoreCase(field.name, ac_real) or
                ascii.eqlIgnoreCase(@typeName(field.field_type), ac_real)
            ) {
                actor_type = @unionInit(actor.ActorType, field.name, try field.field_type.init(&game));
                break;
            }
        } else {
            std.log.err("{s} is not a valid actor", .{ac_real});
            try _write_types();
            std.os.exit(0);
        }
    } else {
        std.log.err("an actor must be specified", .{});
        try clap.help(std.io.getStdErr().writer(), &params);
        try _write_types();
        std.os.exit(0);
    }
    
    // FIXME: This is the last thing that needs to be cleaned up for easier generic implementations
    // TODO: figure out a way to go over the types in the switch o
    var ai: Actor = switch (actor_type) {
        .phc => |*val| val.*.actor(),
        .ct => |*val| val.*.actor(),
        .dhcr => |*val| val.*.actor(),
        .fr => |*val| val.*.actor(),
        .zz => |*val| val.*.actor(),
    };

    defer switch (actor_type) {
        .phc => |*val| val.*.deinit(),
        .ct => |*val| val.*.deinit(),
        .dhcr => |*val| val.*.deinit(),
        .fr => |*val| val.*.deinit(),
        .zz => |*val| val.*.deinit(),
    };

    var steps: usize = 0;
    var total_steps: usize = 0;
    var iterations: usize = 0;

    var run_times: []f64 = try ac.alloc(f64, if (benchmark==0) 1 else benchmark);
    defer ac.free(run_times);

    var timer = try std.time.Timer.start();
    var fps_timer = try std.time.Timer.start();

    var min_time: f64 = std.math.f64_max;
    var max_time: f64 = 0.0;

    var time = Time{};
    time.fixed_time = @floatToInt(u64, interval*@intToFloat(f64, std.time.ns_per_s));

    mainLoop: while (true) {
        if (benchmark == 0) {
            while (sdl.pollEvent()) |ev| {
                switch (ev) {
                    .quit => break :mainLoop,
                    else => {},
                }
            }
        }

        try game.step(&ai);
        steps += 1;
        total_steps += 1;

        if (game.snake.body.items.len == game.board.size.area()) {
            const cur_lap = fps_timer.lap();

            var tf = @intToFloat(f64, cur_lap)/@intToFloat(f64, std.time.ns_per_ms);
            run_times[iterations] = tf;
            iterations += 1;
            if (benchmark == 0) break :mainLoop;

            max_time = @maximum(tf, max_time);
            min_time = @minimum(tf, min_time);

            time.advance_frame(cur_lap);
            if (time.step_fixed_update()) 
                std.log.err("run: {}, steps: {} time: {d:.4}ms steps/apple: {d:.2}", .{
                    iterations, steps, tf,
                    @intToFloat(f32, steps+1)/@intToFloat(f32, game.board.size.area()),
                });
            if (iterations == benchmark) break :mainLoop;

            steps = 0;
            // used instead of shrinkAndFree because:
            // adma crashes when trying to shrink bucket sizes
            // no real reason to free the snake body anyway, since it'll juts be reused anyway
            game.reset();
        }

        if (benchmark == 0) {
            try renderer.setColorRGB(0, 0, 0);
            try renderer.clear();
            
            try game.draw(&renderer, &ai);

            renderer.present();

            time.advance_frame(fps_timer.lap());

            if (time.step_fixed_update()) {
                std.log.err("fps: {d:.2}", .{@intToFloat(f64, std.time.ns_per_s)/@intToFloat(f64, time.delta_time)});
            }
        }
    }

    const t = @intToFloat(f64, timer.read())/@intToFloat(f64, std.time.ns_per_ms);
    const avg_time = t/@intToFloat(f64, iterations);

    var dev: f64 = 0;
    
    for (run_times) |curt| {
        dev += std.math.absFloat(curt-avg_time);
    }
    dev /= @intToFloat(f64, iterations);


    std.log.err(
        "summary\n\tboard size: {}x{}, actor: {s}\n\ttime: {d:.4}s\n\titerations: {}\n\taverage steps: {d:.2}\n\tcycles/s: {d:.0}\n\tavg run: {d:.4}ms ±{d:.4}", 
        .{
            game.board.size.w, game.board.size.h, act_str, t/1000,iterations, 
            @intToFloat(f64, total_steps)/@intToFloat(f64, iterations),
            @intToFloat(f64, total_steps)/(t/1000), avg_time, dev,
        }
    );
}

fn _write_types() !void {
    const writer = std.io.getStdErr().writer();
    _ = try writer.write("Currently avaliable actors:\n");
    inline for (meta.fields(actor.ActorType)) |field| {
        _ = try writer.print("\t{s} or {s}\n", .{field.name, @typeName(field.field_type)});
    }
}