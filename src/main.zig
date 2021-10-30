const std = @import("std");
const sdl = @import("sdl2");

const abs = std.math.absInt;

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

        if (arena.getCell(head.x, head.y).* == .food) { 
            try snake.items.append(tail);
            arena.newApple();
        }
        else arena.getCell(tail.x, tail.y).* = .none;

        arena.getCell(tst.x, tst.y).* = .snake;
    }

    fn frontClear(snake: *Snake) bool {
        const head = snake.items.items[0];
        return switch (snake.dir) {
            .up => head.y > 0 and arena.getCell(head.x, head.y-1).* != .snake,
            .down => head.y < arena.h and arena.getCell(head.x, head.y+1).* != .snake,
            .left => head.x > 0 and arena.getCell(head.x-1, head.y).* != .snake,
            .right => head.x < arena.w and arena.getCell(head.x+1, head.y).* != .snake,
        };
    }

};

const arena = struct {
    pub const w: u32 = 50;
    pub const h: u32 = 50;
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

    pub fn getCell(x: usize, y: usize) *arena.State {
        if (x >= w) @panic("out of bounds");
        if (y >= h) @panic("out of bounds");
        return &grid[x+y*w];
    }
    
    pub fn draw(renderer: *sdl.Renderer) !void {

        // draw cells
        {
            var x: i32 = 0;
            var y: i32 = 0;

            while (y < w) : (y += 1) {
                x = 0;
                while(x < w) : (x += 1) {
                    var cell = getCell(@intCast(usize, x), @intCast(usize, y));

                    try switch (cell.*) {
                        .none => continue,
                        .snake => renderer.setColorRGB(0x00, 0xf5, 0x00),
                        .food => renderer.setColorRGB(0xf5, 0x00, 0x00),
                    };
                    try renderer.fillRect(sdl.Rectangle{
                        .x = x*cell_size.w-1,
                        .y = y*cell_size.h-1,
                        .width = @intCast(i32, cell_size.w)-1,
                        .height = @intCast(i32, cell_size.h)-1,
                    });
                }
            }
        }

        // draw lines 
        // {
        //     try renderer.setColorRGB(0, 0, 0);
        //     var c: i32 = 0;
        //     var r: i32 = 0;

        //     while (c < w+1) : (c += 1) {
        //         try renderer.drawLine(c*cell_size.w, 0, c*cell_size.w, win.h);
        //     }
        //     while (r < h+1) : (r += 1) {
        //         try renderer.drawLine(0, r*cell_size.h, win.w, r*cell_size.h);
        //     }
        // }
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
    arena.rand = &std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())).random();

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
        arena.getCell(pos.x, pos.y).* = .snake;
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

            if ((try abs(diff_y)) > (try abs(diff_x)))
                snake.dir = if(diff_y < 0) .up else .down
            else
                snake.dir = if(diff_x < 0) .left else .right;

            const start_dir = snake.dir;
            while (!snake.frontClear()) {    
                if (arena.rand.boolean()) {
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

            try snake.move();
        }
        
        frame += 1;

        try renderer.setColorRGB(0, 0, 0);
        try renderer.clear();
        
        try arena.draw(&renderer);

        renderer.present();
    }
}
