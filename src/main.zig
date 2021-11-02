const std = @import("std");
const sdl = @import("sdl2");

const abs = std.math.absInt;
const divC = std.math.divCeil;

const win = .{.w = 720, .h = 720};

const Pos = struct {
    x: usize,
    y: usize,
};

const Snake = struct {
    const Direction = enum{
        up,
        down,
        left,
        right
    };

    items: std.ArrayList(Pos),
    dir: Direction = .right,

    pub fn move(snake: *Snake) !void {
        var tail = snake.items.items[snake.items.items.len-1];

        var slice = snake.items.items;
        var head = &slice[0];

        var prev = head.*;

        switch (snake.dir) {
            .right => head.x += 1,
            .left => head.x -= 1,
            .up => head.y -= 1,
            .down => head.y += 1,
        }

        const tst = head.*;

        for (slice[1..]) |*item| {
            var temp = prev;
            prev = item.*;
            item.* = temp;
        }

        if ((try arena.getCell(head.x, head.y)).* == .food) { 
            try snake.items.append(tail);
            arena.newApple();
        }
        else (try arena.getCell(tail.x, tail.y)).* = .none;

        (try arena.getCell(tst.x, tst.y)).* = .snake;
    }

    fn frontClear(snake: *Snake) bool {
        const head = snake.items.items[0];
        const s = &arena.State.snake;
        const ahead_has_exit = switch (snake.dir) {
            .up => 
                (arena.getCell(head.x-%1, head.y-%1) catch s).* != .snake
                or (arena.getCell(head.x+1, head.y-%1) catch s).* != .snake
                or (arena.getCell(head.x, head.y-%2) catch s).* != .snake,
            .down =>
                ((arena.getCell(head.x-%1, head.y+%1) catch s).* != .snake
                or (arena.getCell(head.x+1, head.y+1) catch s).* != .snake
                or (arena.getCell(head.x, head.y+2) catch s).* != .snake),
            .left =>
                ((arena.getCell(head.x-%1, head.y-%1) catch s).* != .snake
                or (arena.getCell(head.x-%1, head.y+1) catch s).* != .snake
                or (arena.getCell(head.x-%2, head.y) catch s).* != .snake),
            .right =>
                ((arena.getCell(head.x+1, head.y-%1) catch s).* != .snake
                or (arena.getCell(head.x+1, head.y+1) catch s).* != .snake
                or (arena.getCell(head.x+2, head.y) catch s).* != .snake),
        };
        const direct_clear = switch (snake.dir) {
            .up => head.y > 0 and (arena.getCell(head.x, head.y-1) catch s).* != .snake,
            .down => head.y < arena.h-1 and (arena.getCell(head.x, head.y+1) catch s).* != .snake,
            .left => head.x > 0 and (arena.getCell(head.x-1, head.y) catch s).* != .snake,
            .right => head.x < arena.w-1 and (arena.getCell(head.x+1, head.y) catch s).* != .snake,
        };
        return direct_clear and ahead_has_exit;
    }

    fn draw(snake: *Snake, renderer: *sdl.Renderer) !void {
        try renderer.setColorRGB(0x0, 0xf5, 0x0);

        var prev: ?Pos = null;

        //var prev: ?Pos = null;
        for (snake.items.items) |seg, i| {

            //3/4 of cell size;
            const cx = try divC(usize, (arena.cell_size.w*3), 4);
            const cy = try divC(usize, (arena.cell_size.h*3), 4);
            const fx = try divC(usize, arena.cell_size.w, 8);
            const fy = try divC(usize, arena.cell_size.h, 8);

            // first, draw the base rect
            try renderer.fillRect(sdl.Rectangle{
                .x = @intCast(i32, seg.x*arena.cell_size.w+fx),
                .y = @intCast(i32, seg.y*arena.cell_size.w+fy),
                .width = @intCast(i32, cx),
                .height = @intCast(i32, cy),
            });

            // draw connection to next segment
            if (i != snake.items.items.len-1) {
                const next = snake.items.items[i+1];

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

                const x = switch(dir_next) {
                    .left => 0,
                    .up, .down => fx,
                    .right => fx+cx,
                };
                const y = switch(dir_next) {
                    .up => 0,
                    .left, .right, => fy,
                    .down => fy+cy,
                };
                const width = switch(dir_next) {
                    .left, .right => fx,
                    .up, .down => cx,
                };
                const height = switch(dir_next) {
                    .up, .down => fy,
                    .left, .right => cy,
                };

                try renderer.fillRect(sdl.Rectangle{
                    .x = @intCast(i32, seg.x*arena.cell_size.w+x),
                    .y = @intCast(i32, seg.y*arena.cell_size.h+y),
                    .width = @intCast(i32, width),
                    .height = @intCast(i32, height),
                });
            }

            if (prev) |next| {

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

                const x = switch(dir_next) {
                    .left => 0,
                    .up, .down => fx,
                    .right => fx+cx,
                };
                const y = switch(dir_next) {
                    .up => 0,
                    .left, .right, => fy,
                    .down => fy+cy,
                };
                const width = switch(dir_next) {
                    .left, .right => fx,
                    .up, .down => cx,
                };
                const height = switch(dir_next) {
                    .up, .down => fy,
                    .left, .right => cy,
                };

                try renderer.fillRect(sdl.Rectangle{
                    .x = @intCast(i32, seg.x*arena.cell_size.w+x),
                    .y = @intCast(i32, seg.y*arena.cell_size.h+y),
                    .width = @intCast(i32, width),
                    .height = @intCast(i32, height),
                });
            }

            prev = seg;
        }
    }
};

const arena = struct {
    pub const w: u32 = 30;
    pub const h: u32 = 30;
    pub const size: u32 = w*h;
    pub const cell_size = .{.w = win.w/w, .h = win.h/h};
    pub var rand: *std.rand.Random = undefined;

    pub const State = enum{
        none,
        snake,
        food,
    };

    pub var grid = [_]State{State.none}**size;
    pub var apple: Pos = undefined;

    pub fn getCell(x: usize, y: usize) error{OutOfBounds}!*arena.State {
        if (x >= w) return error.OutOfBounds;
        if (y >= h) return error.OutOfBounds;
        return &grid[x+y*w];
    }
    
    pub fn draw(renderer: *sdl.Renderer) !void {

        try renderer.setColorRGB(0xf5, 0x00, 0x00);
        try renderer.fillRect(sdl.Rectangle{
            .x = @intCast(i32, apple.x*cell_size.w+(try divC(usize, cell_size.w, 4))),
            .y = @intCast(i32, apple.y*cell_size.h+(try divC(usize, cell_size.h, 4))),
            .width = try divC(i32, cell_size.w, 2),
            .height = try divC(i32, cell_size.h, 2),
        });

        // draw lines 
        {
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
        
        while (grid[new_pos] == .snake and new_pos > 0 and new_pos < size) {
            if (left) {
                new_pos -= 1;
                if(new_pos < 1){left=false;new_pos=orig;}
            } else {
                new_pos += 1;
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

    try sdl.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer sdl.quit();

    var window = try sdl.createWindow(
        "snake",
        .{ .centered = {} }, .{ .centered = {} },
        win.w, win.h,
        .{ .shown = true },
    );
    defer window.destroy();
    
    var renderer = try sdl.createRenderer(window, null, .{ .accelerated = true, .present_vsync = true });
    defer renderer.destroy();

    try renderer.setDrawBlendMode(sdl.c.SDL_BLENDMODE_BLEND);

    arena.rand = &std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())).random;

    var snake = Snake{
        .items = std.ArrayList(Pos).init(ac),
    };
    defer snake.items.deinit();

    const mid = arena.w/2;
    try snake.items.appendSlice(&[2]Pos{
        .{.x=mid, .y=arena.h/2}, 
        .{.x=mid-1, .y=arena.h/2},
    });

    for (snake.items.items) |pos| {
        (try arena.getCell(pos.x, pos.y)).* = .snake;
    }

    arena.newApple();

    var frame: usize = 0;
    mainLoop: while (true) {
        while (sdl.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainLoop,
                else => {},
            }
        }

        if (@mod(frame, 1) == 0) {

            const head = snake.items.items[0];
            var diff_x: isize = @intCast(isize, arena.apple.x) - @intCast(isize, head.x);
            var diff_y: isize = @intCast(isize, arena.apple.y) - @intCast(isize, head.y);

            if (@maximum(try abs(diff_x), try abs(diff_y)) == try abs(diff_x))
                snake.dir = if(diff_x < 0) .left else .right
            else
                snake.dir = if(diff_y < 0) .up else .down;

            if (!snake.frontClear()) {
                const start_dir = snake.dir;

                var top_left: usize = 0;
                var top_right: usize = 0;
                var bottom_left: usize = 0;
                var bottom_right: usize = 0;                

                for (snake.items.items) |seg, i| {
                    if (i > snake.items.items.len/3) break; // simpler way to ignore the snake's tail
                    if (seg.x <= head.x and seg.y < head.y) top_left += 1;
                    if (seg.x > head.x and seg.y <= head.y) top_right += 1;
                    if (seg.y <= head.y and seg.x < head.x) bottom_left += 1;
                    if (seg.y > head.y and seg.x >= head.x) bottom_right += 1;
                }

                const left = switch (snake.dir) {
                    .left => @minimum(bottom_left, top_left) == bottom_left,
                    .right => @minimum(top_right, bottom_right) == top_right,
                    .up => @minimum(top_left, top_right) == top_left,
                    .down => @minimum(bottom_right, bottom_left) == bottom_right,
                };

                // const left = arena.rand.boolean();
                while (!snake.frontClear()) {
                    if (left) {
                        snake.dir = switch (snake.dir) {
                            .up => .left,
                            .left => .down,
                            .down => .right,
                            .right => .up,
                        };
                    } else {
                        snake.dir = switch (snake.dir) {
                            .up => .right,
                            .right => .down,
                            .down => .left,
                            .left => .up,
                        };
                    }

                    if (start_dir == snake.dir) @panic("stuck in loop");
                }
            }

            try snake.move();
        }
        
        frame += 1;

        try renderer.setColorRGB(0, 0, 0);
        try renderer.clear();
        
        try arena.draw(&renderer);
        try snake.draw(&renderer);

        renderer.present();
    }
}
