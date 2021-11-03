const std = @import("std");
const sdl = @import("sdl2");

const abs = std.math.absInt;
const divC = std.math.divCeil;

const win = .{.w = 720, .h = 720};

const arena = struct {
    pub const w: u32 = 10;
    pub const h: u32 = 10;
    pub const size: u32 = w*h;
    pub const cell_size = .{.w = win.w/w, .h = win.h/h};
    pub var rand: *std.rand.Random = undefined;

    pub const State = enum{
        none,
        snake,
        food,
    };

    pub var grid = [_]State{State.none}**size;
    pub var path = [_]Snake.Direction{Snake.Direction.down}**size;
    pub var apple: Pos = undefined;

    pub fn getCell(x: usize, y: usize) error{OutOfBounds}!*arena.State {
        if (x >= w) return error.OutOfBounds;
        if (y >= h) return error.OutOfBounds;
        return &grid[x+y*w];
    }

    pub fn getPath(x: usize, y: usize) error{OutOfBounds}!*Snake.Direction {
        if (x >= w) return error.OutOfBounds;
        if (y >= h) return error.OutOfBounds;
        return &path[x+y*w];
    }
    
    pub fn draw(renderer: *sdl.Renderer) !void {

        // draw path
        {
            try renderer.setColorRGBA(5, 252, 240, 255);

            const hcx = cell_size.w/2;
            const hcy = cell_size.h/2;

            for (path) |item, i| {
                const item_pos = .{.x=i%w, .y=i/w};
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

    arena.rand = &std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())).random();

    var snake = Snake{
        .body = std.ArrayList(Pos).init(ac),
    };
    defer snake.body.deinit();

    try snake.body.appendSlice(&[2]Pos{
        .{.x=0, .y=1}, 
        .{.x=0, .y=0},
    });

    for (snake.body.items) |pos| {
        (try arena.getCell(pos.x, pos.y)).* = .snake;
    }

    // create simple hamilton path
    // note: this code only works on
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
    (try arena.getPath(0, 0)).* = .down;


    arena.newApple();

    var frame: usize = 0;
    mainLoop: while (snake.body.items.len < arena.size-1) {
        while (sdl.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainLoop,
                else => {},
            }
        }

        if (@mod(frame, 10) == 0) {
            const head = snake.body.items[0];
            snake.dir = (try arena.getPath(head.x, head.y)).*;

            if (arena.apple.x >= head.x and head.y != 0 and arena.apple.y != 0) {
                snake.dir = blk: {
                    if (arena.apple.y == head.y) {
                        for (snake.body.items) |seg| {
                            if (seg.y == 0) continue;
                            if (seg.x > head.x and seg.x <= arena.apple.x) break :blk snake.dir;
                        }

                        break :blk .right;
                    }

                    break :blk snake.dir;
                };
            } else {
                snake.dir = blk: {
                    if (head.y == 0 or head.x == arena.w-1) break :blk snake.dir;

                    for (snake.body.items) |seg| {
                        if (seg.y == 0) continue;
                        if (seg.x > head.x) break :blk snake.dir;
                    }

                    break :blk .right;
                };
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

    std.log.err("congrats u won bb", .{});
    std.time.sleep(std.time.ns_per_s*5);
}

const Pos = struct {
    x: usize,
    y: usize,

    fn isEqual(a: *Pos, b: *Pos) bool {
        return a.x == b.x and a.y == b.y;
    }
};

const Snake = struct {
    const Direction = enum{
        up,
        down,
        left,
        right
    };

    body: std.ArrayList(Pos),
    dir: Direction = .right,

    pub fn move(snake: *Snake) !void {
        var slice = snake.body.items;
        var tail = slice[slice.len-1];
        
        var head = &slice[0];

        switch (snake.dir) {
            .right => head.x += 1,
            .left => head.x -= 1,
            .up => head.y -= 1,
            .down => head.y += 1,
        }

        var prev = head.*;
        for (slice[1..]) |*item| {
            var temp = prev;
            prev = item.*;
            item.* = temp;
        }

        // update grid with new cell head
        (try arena.getCell(head.x, head.y)).* = .snake;

        if (head.isEqual(&arena.apple)) { 
            try snake.body.append(tail);
            arena.newApple();
        }
        else (try arena.getCell(tail.x, tail.y)).* = .none;

    }

    // fancy snake directional drawing
    fn draw(snake: *Snake, renderer: *sdl.Renderer) !void {
        try renderer.setColorRGB(0x0, 0xf5, 0x0);

        var prev: ?Pos = null;

        //var prev: ?Pos = null;
        for (snake.body.items) |seg, i| {

            //3/4 of cell size;
            const cx = try divC(usize, (arena.cell_size.w*3), 4);
            const cy = try divC(usize, (arena.cell_size.h*3), 4);
            const fx = try divC(usize, arena.cell_size.w, 8);
            const fy = try divC(usize, arena.cell_size.h, 8);

            // first, draw the base rect
            try renderer.fillRect(sdl.Rectangle{
                .x = @intCast(i32, seg.x*arena.cell_size.w+fx),
                .y = @intCast(i32, seg.y*arena.cell_size.h+fy),
                .width = @intCast(i32, cx),
                .height = @intCast(i32, cy),
            });

            // draw connection to next segment
            if (i != snake.body.items.len-1) {
                const next = snake.body.items[i+1];

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