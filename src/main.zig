const std = @import("std");
const sdl = @import("sdl2");
const clap = @import("clap");

const abs = std.math.absInt;
const divC = std.math.divCeil;
const divF = std.math.divFloor;
const divT = std.math.divTrunc;

const win = .{.w = 800, .h = 800};

const Size = struct {
    w: i32,
    h: i32,
};

pub fn rect(renderer: *sdl.Renderer, r: sdl.Rectangle) !void {
    if (arena.wireframe) {
        try renderer.drawRect(r);
    } else {
        try renderer.fillRect(r);
    }
}

const arena = struct {
    pub var w: u32 = undefined;
    pub var h: u32 = undefined;
    pub var size: u32 = undefined;
    pub var cell_size = Size{.w = 0, .h = 0};
    pub var rand: *std.rand.Random = undefined;

    pub var render_path = true;
    pub var wireframe = false;

    pub var benchmark: usize = undefined;

    pub const State = enum{
        none,
        snake,
        food,
    };

    pub var grid: []State = undefined;
    pub var path: []Direction = undefined;
    pub var path_order: []usize = undefined;

    pub var apple: Pos = undefined;

    pub fn getCell(x: usize, y: usize) error{OutOfBounds}!*arena.State {
        if (x >= w) return error.OutOfBounds;
        if (y >= h) return error.OutOfBounds;
        return &grid[x+y*w];
    }

    pub fn getPath(x: usize, y: usize) error{OutOfBounds}!*Direction {
        if (x >= w) return error.OutOfBounds;
        if (y >= h) return error.OutOfBounds;
        return &path[x+y*w];
    }

    pub fn getPathOrder(x: usize, y: usize) *usize {
        // if (x >= w) return error.OutOfBounds;
        // if (y >= h) return error.OutOfBounds;
        return &path_order[x+y*w];
    }
    
    pub fn draw(renderer: *sdl.Renderer) !void {

        // draw path
        if (render_path) {
            try renderer.setColorRGBA(5, 252, 240, 90);

            const hcx = @divFloor(cell_size.w, 2);
            const hcy = @divFloor(cell_size.h, 2);

            for (path) |item, i| {
                const item_pos = .{.x=@intCast(i32, i%w), .y=@intCast(i32, i/w)};
                switch (item) {
                    .right => try renderer.drawLine(
                        @intCast(i32, item_pos.x*cell_size.w+hcx),
                        @intCast(i32, item_pos.y*cell_size.h+hcy),
                        @intCast(i32, (item_pos.x+1)*cell_size.w+hcx)-1,
                        @intCast(i32, item_pos.y*cell_size.h+hcy),
                    ),
                    .left => try renderer.drawLine(
                        @intCast(i32, item_pos.x*cell_size.w+hcx),
                        @intCast(i32, item_pos.y*cell_size.h+hcy),
                        @intCast(i32, (item_pos.x-1)*cell_size.w+hcx)+1,
                        @intCast(i32, item_pos.y*cell_size.h+hcy),
                    ),
                    .up => try renderer.drawLine(
                        @intCast(i32, item_pos.x*cell_size.w+hcx),
                        @intCast(i32, item_pos.y*cell_size.h+hcy),
                        @intCast(i32, item_pos.x*cell_size.w+hcx),
                        @intCast(i32, (item_pos.y-1)*cell_size.h+hcy)+1,
                    ),
                    .down => try renderer.drawLine(
                        @intCast(i32, item_pos.x*cell_size.w+hcx),
                        @intCast(i32, item_pos.y*cell_size.h+hcy),
                        @intCast(i32, item_pos.x*cell_size.w+hcx),
                        @intCast(i32, (item_pos.y+1)*cell_size.h+hcy)-1,
                    ),
                }
            }
        }

        try renderer.setColorRGB(0xf5, 0x00, 0x00);
        try rect(renderer, sdl.Rectangle{
            .x = @intCast(i32, apple.x)*cell_size.w+(try divC(i32, cell_size.w, 4)),
            .y = @intCast(i32, apple.y)*cell_size.h+(try divC(i32, cell_size.h, 4)),
            .width = try divC(i32, cell_size.w, 2),
            .height = try divC(i32, cell_size.h, 2),
        });

        { // draw lines
            try renderer.setColorRGBA(127, 127, 127, 90);
            var c: i32 = 0;
            var r: i32 = 0;

            while (c < w+1) : (c += 1) {
                try renderer.drawLine(c*cell_size.w, 0, c*cell_size.w, win.h);
            }
            while (r < h+1) : (r += 1) {
                try renderer.drawLine(0, r*cell_size.h, win.w, r*cell_size.h);
            }
        }
    }

    pub fn newApple() void {
        var new_pos = rand.uintLessThan(usize, @as(usize,size));

        var left = rand.boolean();

        const orig = new_pos;
        
        while (grid[new_pos] == .snake) {
            if (left) {
                if(new_pos == 0){left=false;new_pos=orig;}
                else new_pos -= 1;
            } else {
                if(new_pos == size-1) {left=true;new_pos=orig;}
                else new_pos += 1;
            }
        }

        grid[new_pos] = .food;

        apple = .{.x = new_pos % w, .y = new_pos/h};
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const ac = &gpa.allocator;

    const params = comptime [_]clap.Param(clap.Help){
        try clap.parseParam("-h, --help Display this and exit"),
        try clap.parseParam("-s, --size <NUM> Snake board size"),
        try clap.parseParam("-p, --paths Enable path rendering"),
        try clap.parseParam("-w, --wireframe Render snake body outlines"),
        try clap.parseParam("-b, --benchmark <NUM> Do render free benchmarking based on # of iterations"),
        try clap.parseParam("-z, --zoom Disable vsync to run as fast as possible"),
        try clap.parseParam("-m, --messages <NUM> Amount of messages during benchmarking"),
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

    const messages = try std.fmt.parseUnsigned(usize, args.option("--messages") orelse "10", 10);

    const size = try std.fmt.parseUnsigned(u32, args.option("--size") orelse "20", 10);
    arena.w = size;
    arena.h = size;
    arena.size = arena.w*arena.h;
    arena.cell_size = .{
        .w=@divFloor(win.w, @intCast(i32, arena.w)),
        .h=@divFloor(win.h, @intCast(i32, arena.h)),
    };

    arena.grid = try ac.alloc(arena.State, size*size);
    arena.path = try ac.alloc(Direction, size*size);
    arena.path_order = try ac.alloc(usize, size*size);

    defer ac.free(arena.grid);
    defer ac.free(arena.path);
    defer ac.free(arena.path_order);

    var renderer: sdl.Renderer = undefined;
    var window: sdl.Window = undefined;
    try sdl.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer sdl.quit();

    defer window.destroy();
    defer renderer.destroy();

    if (arena.benchmark == 0) {

        window = try sdl.createWindow(
            "snake",
            .{ .centered = {} }, .{ .centered = {} },
            win.w, win.h,
            .{ .shown = true },
        );
        
        renderer = try sdl.createRenderer(
            window, null, 
            .{ .accelerated = true, .present_vsync=!args.flag("--zoom") }
        );
        try renderer.setDrawBlendMode(sdl.c.SDL_BLENDMODE_BLEND);
    }

    arena.rand = &std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())).random();

    var snake = Snake{
        .body = std.ArrayList(Pos).init(ac),
    };
    defer snake.body.deinit();
    try snake.body.append(.{.x=0, .y=0});

    for (snake.body.items) |pos| {
        (try arena.getCell(pos.x, pos.y)).* = .snake;
    }

    // create simple hamilton path
    // note: this code only works on evenly sized grids
    var i: usize  = 0;
    while (i < arena.w) : (i+= 1) {
        (try arena.getPath(i, 0)).* = .left; // line across top row
        (try arena.getPath(i, arena.h-1)).* = if (i%2==0) .right else .up; // bottom zigzags

        // lines up and down
        var j: usize = 1;
        while(j < arena.h-1) : (j+=1) {
            (try arena.getPath(i, j)).* = if (i%2==0) .down else .up;
        }

        if (i > 0 and i < arena.w-1) { // top zigzags
            (try arena.getPath(i, 1)).* = if (i%2==0) .down else .right;
        }
    }
    (try arena.getPath(0, 0)).* = .down; // top left corner

    { // cycle ordering for skips
        var cur_pos = Pos{.x=0, .y=0};
        var ordering: usize = 0;
        while (ordering < arena.size) : (ordering += 1) {
            arena.getPathOrder(cur_pos.x, cur_pos.y).* = ordering;
            cur_pos = cur_pos.move((try arena.getPath(cur_pos.x, cur_pos.y)).*);
        }
    }

    arena.newApple();

    var frame: usize = 0;
    var steps: usize = 0;
    var total_steps: usize = 0;
    var iterations: usize = 0;

    var timer = try std.time.Timer.start();
    var per_run_timer = try std.time.Timer.start();

    const log_freq = if (messages != 0) arena.benchmark/messages else 0;
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
            var head = snake.body.items[0];
            var tail = snake.body.items[snake.body.items.len-1];
            snake.dir = (try arena.getPath(head.x, head.y)).*;

            const dist_apple = head.cycleDistance(&arena.apple);
            const dist_tail = head.cycleDistance(&tail);
            var dist_next: isize = 1;
            var max_shortcut = @minimum(dist_apple, dist_tail-3);

            if (dist_apple < dist_tail) {
                max_shortcut -= 1;
                // might run into some apples along the way
                if ((dist_tail - dist_apple) * 4 > (arena.size-snake.body.items.len)) max_shortcut -= 10;
            }

            if (snake.body.items.len > (arena.size*5)/8) max_shortcut = 0; // just follow the path when the board is mostly filled
            if (max_shortcut > 0) {

                // zig coming in clutch with fancy meta stuff
                for (std.enums.values(Direction)) |dir| {
                    var b = head.move(dir);

                    if ((arena.getCell(b.x, b.y) catch &arena.State.snake).* != .snake) {
                        const dist_b = head.cycleDistance(&b);
                        if (dist_b <= max_shortcut and dist_b > dist_next) {
                            snake.dir = dir;
                            dist_next = dist_b;
                        }
                    }
                }

            }

            try snake.move();
            steps += 1;
            total_steps += 1;

            if (snake.body.items.len == arena.size) {
                const cur_lap = per_run_timer.lap();
                iterations += 1;

                if (arena.benchmark == 0) break :mainLoop;

                

                if (log_freq != 0 and @mod(iterations, log_freq) == 0) 
                    std.log.err("run: {}, steps: {} time: {d:.4}s steps/apple: {d:.2}", .{
                        iterations, steps, 
                        @intToFloat(f64, cur_lap)/@intToFloat(f64, std.time.ns_per_s),
                        @intToFloat(f32, steps+1)/@intToFloat(f32, arena.size)
                    });
                if (iterations == arena.benchmark) break :mainLoop;

                steps = 0;
                snake.body.shrinkAndFree(1);
                snake.body.items[0] = Pos{.x=0, .y=0};
            }
        }
        frame += 1;

        if (arena.benchmark == 0) {
            try renderer.setColorRGB(0, 0, 0);
            try renderer.clear();
            
            try arena.draw(&renderer);
            try snake.draw(&renderer);

            renderer.present();
        }
    }
    
    std.log.err("\ntime: {d:.4}s\niterations: {}\naverage steps: {d:.2}\nboard size: {}x{}", .{
        @intToFloat(f64, timer.read())/@intToFloat(f64, std.time.ns_per_s),
        iterations, @intToFloat(f64, total_steps)/@intToFloat(f64, iterations),
        arena.w, arena.h
    });
}

const Pos = struct {
    x: usize,
    y: usize,

    fn isEqual(a: *Pos, b: *Pos) bool {
        return a.x == b.x and a.y == b.y;
    }

    pub fn cycleDistance(a: *Pos, b: *Pos) isize {
        const order_a = @intCast(isize, arena.getPathOrder(a.x, a.y).*);
        const order_b = @intCast(isize, arena.getPathOrder(b.x, b.y).*);
        if (order_a < order_b) return order_b - order_a;
        
        return order_b - order_a + arena.size;
    }

    fn move(pos: Pos, dir: Direction) Pos {
        var p = pos;
        switch (dir) {
            .right => p.x += 1,
            .left => p.x -%= 1,
            .up => p.y -%= 1,
            .down => p.y += 1,
        }

        return p;
    }
};

const Direction = enum{
    up,
    down,
    left,
    right
};

const Snake = struct {
    body: std.ArrayList(Pos),
    dir: Direction = .right,

    pub fn move(snake: *Snake) !void {
        var slice = snake.body.items;
        var tail = slice[slice.len-1];

        var head = &slice[0];
        var prev = slice[0];

        switch (snake.dir) {
            .right => head.x += 1,
            .left => head.x -= 1,
            .up => head.y -= 1,
            .down => head.y += 1,
        }

        for (slice[1..]) |*item| {
            std.mem.swap(Pos, item, &prev); // no more accidental pointer conundrums
        }

        // update grid with new cell head
        (try arena.getCell(head.x, head.y)).* = .snake;

        if (head.isEqual(&arena.apple)) { 
            try snake.body.append(tail);
            if (snake.body.items.len < arena.size) arena.newApple();
        }
        else (try arena.getCell(tail.x, tail.y)).* = .none; // remove the tail from the grid
    }

    fn draw(snake: *Snake, renderer: *sdl.Renderer) !void {
        const cell_size = arena.cell_size;
        const hcx = @divFloor(cell_size.w, 2);
        const hcy = @divFloor(cell_size.h, 2);

        // TODO: improve path rendering with the same method as snake rendering
        if (arena.render_path) {
            var cur_pos = snake.body.items[0];

            try renderer.setColorRGBA(0xfc, 0x74, 0x19, 0xf5);

            while (!cur_pos.isEqual(&arena.apple)) {

                var tail = snake.body.items[snake.body.items.len-1];
                var ideal_dir = (try arena.getPath(cur_pos.x, cur_pos.y)).*;

                const dist_apple = cur_pos.cycleDistance(&arena.apple);
                const dist_tail = cur_pos.cycleDistance(&tail);
                var dist_next: isize = 1;
                var max_shortcut = @minimum(dist_apple, dist_tail-3);

                if (dist_apple < dist_tail) {
                    max_shortcut -= 1;
                    if ((dist_tail - dist_apple) * 4 > (arena.size-snake.body.items.len)) max_shortcut -= 10;
                }

                if (snake.body.items.len > (arena.size*5)/8) max_shortcut = 0;
                if (max_shortcut > 0) {
                    for (std.enums.values(Direction)) |dir| {
                        var b = cur_pos.move(dir);

                        if ((arena.getCell(b.x, b.y) catch &arena.State.snake).* != .snake) {
                            const dist_b = cur_pos.cycleDistance(&b);
                            if (dist_b <= max_shortcut and dist_b > dist_next) {
                                ideal_dir = dir;
                                dist_next = dist_b;
                            }
                        }
                    }
                }

                switch (ideal_dir) {
                    .right => try renderer.drawLine(
                        @intCast(i32, cur_pos.x)*cell_size.w+hcx,
                        @intCast(i32, cur_pos.y)*cell_size.h+hcy,
                        @intCast(i32, (cur_pos.x+1))*cell_size.w+hcx-1,
                        @intCast(i32, cur_pos.y)*cell_size.h+hcy,
                    ),
                    .left => try renderer.drawLine(
                        @intCast(i32, cur_pos.x)*cell_size.w+hcx,
                        @intCast(i32, cur_pos.y)*cell_size.h+hcy,
                        @intCast(i32, (cur_pos.x-1))*cell_size.w+hcx+1,
                        @intCast(i32, cur_pos.y)*cell_size.h+hcy,
                    ),
                    .up => try renderer.drawLine(
                        @intCast(i32, cur_pos.x)*cell_size.w+hcx,
                        @intCast(i32, cur_pos.y)*cell_size.h+hcy,
                        @intCast(i32, cur_pos.x)*cell_size.w+hcx,
                        @intCast(i32, (cur_pos.y-1))*cell_size.h+hcy+1,
                    ),
                    .down => try renderer.drawLine(
                        @intCast(i32, cur_pos.x)*cell_size.w+hcx,
                        @intCast(i32, cur_pos.y)*cell_size.h+hcy,
                        @intCast(i32, cur_pos.x)*cell_size.w+hcx,
                        @intCast(i32, cur_pos.y+1)*cell_size.h+hcy-1,
                    ),
                }

                switch (ideal_dir) {
                    .right => cur_pos.x += 1,
                    .left => cur_pos.x -= 1,
                    .up => cur_pos.y -= 1,
                    .down => cur_pos.y += 1,
                }
            }
        }

        //3/4 of cell size;
        
        const fx = (try divT(i32, arena.cell_size.w, 8));
        const fy = (try divT(i32, arena.cell_size.h, 8));

        const cx = fx*6;
        const cy = fy*6;

        var prev: ?Pos = null;

        var cur_pos: Pos = snake.body.items[0];
        var cur_dir: Direction = undefined;

        var col = sdl.Color.rgb(0, 255, 0);

        var con_tail = false;

        for (snake.body.items) |_, i| {
            var seg = snake.body.items[i];

            try renderer.setColor(col);

            if (i != snake.body.items.len-1) {
                var next = snake.body.items[i+1];

                const diff_x = @intCast(isize, next.x) - @intCast(isize, seg.x);
                const diff_y = @intCast(isize, next.y) - @intCast(isize, seg.y);

                var dir_next: Direction = undefined;

                dir_next = switch (diff_x) {
                    -1 => .left,
                    1 => .right,
                    else => .up
                };
                if(dir_next != .left and dir_next != .right) {
                    dir_next = switch (diff_y) {
                        -1 => .up,
                        1 => .down,
                        else => .down,
                    };
                }
                
                if (i == 0) {
                    cur_pos = seg;
                    cur_dir = dir_next;
                }

                if (cur_dir != dir_next or i == snake.body.items.len-2) {

                    // incorporate tail into final segment                    
                    if (i == snake.body.items.len-2) {
                        if (cur_dir == dir_next) seg = snake.body.items[snake.body.items.len-1]
                        else con_tail=true;
                    }
                    
                    try rect(renderer, switch (cur_dir) {
                        .left => .{
                            .x = @intCast(i32, seg.x)*cell_size.w+(fx*7),
                            .y = fy+@intCast(i32, seg.y)*cell_size.h,
                            .width = (@intCast(i32, cur_pos.x) - @intCast(i32, seg.x))*cell_size.w,
                            .height = cy,
                        },
                        .right => .{
                            .x = fx+@intCast(i32, cur_pos.x)*cell_size.w,
                            .y = fy+@intCast(i32, cur_pos.y)*cell_size.h,
                            .width = (@intCast(i32, seg.x) - @intCast(i32, cur_pos.x))*cell_size.w,
                            .height = cy,
                        },
                        .up => .{
                            .x = fx+@intCast(i32, seg.x)*cell_size.w,
                            .y = @intCast(i32, seg.y)*cell_size.h+(fy*7),
                            .width = cx,
                            .height = (@intCast(i32, cur_pos.y) - @intCast(i32, seg.y))*cell_size.h,
                        },
                        .down => .{
                            .x = fx+@intCast(i32, cur_pos.x)*cell_size.w,
                            .y = fy+@intCast(i32, cur_pos.y)*cell_size.h,
                            .width = cx,
                            .height = (@intCast(i32, seg.y) - @intCast(i32, cur_pos.y))*cell_size.h,
                        },
                    });

                    cur_pos = seg;
                    cur_dir = dir_next;
                }
            } else {
                const h = @boolToInt((cur_dir == .left or cur_dir == .right) and con_tail);
                const v = @boolToInt((cur_dir == .up or cur_dir == .down) and con_tail);
                // const r = @boolToInt(cur_dir == .left and con_tail);
                // const d = @boolToInt(cur_dir == .up and con_tail);
                try rect(renderer, .{
                    .x=fx+@intCast(i32, if(cur_dir==.right) cur_pos.x else seg.x)*cell_size.w,
                    .y=fy+@intCast(i32, if(cur_dir==.down) cur_pos.y else seg.y)*cell_size.h,
                    .width=cx+cell_size.w*h,
                    .height=cy+cell_size.h*v,
                });
            }

            prev = seg;
        }
    }
};