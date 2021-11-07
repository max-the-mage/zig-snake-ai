const sdl = @import("sdl2");
const std = @import("std");

pub const abs = std.math.absInt;
pub const divC = std.math.divCeil;
pub const divF = std.math.divFloor;
pub const divT = std.math.divTrunc;

pub const arena = struct {
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
    pub var path: []Dir = undefined;
    pub var path_order: []usize = undefined;

    pub var apple: Pos = undefined;

    pub fn getCell(x: usize, y: usize) error{OutOfBounds}!*arena.State {
        if (x >= w) return error.OutOfBounds;
        if (y >= h) return error.OutOfBounds;
        return &grid[x+y*w];
    }

    pub fn getPath(x: usize, y: usize) error{OutOfBounds}!*Dir {
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

            var cur_pos: Pos = .{.x=0, .y=0};
            var base_pos: Pos = cur_pos;
            var prev_dir: Dir = path[0];

            var goal: Pos = .{.x=0, .y=0};

            while (true) {
                const new_dir = (try getPath(cur_pos.x, cur_pos.y)).*;

                if (new_dir != prev_dir) {
                    try renderer.drawLine(
                        @intCast(i32, base_pos.x)*cell_size.w+hcx,
                        @intCast(i32, base_pos.y)*cell_size.h+hcy,
                        @intCast(i32, cur_pos.x)*cell_size.w+hcx,
                        @intCast(i32, cur_pos.y)*cell_size.h+hcy,
                    );

                    prev_dir = new_dir;
                    base_pos = cur_pos;
                }

                cur_pos = cur_pos.move(new_dir);
                if (cur_pos.isEqual(&goal)) {
                    try renderer.drawLine(
                        @intCast(i32, base_pos.x)*cell_size.w+hcx,
                        @intCast(i32, base_pos.y)*cell_size.h+hcy,
                        @intCast(i32, cur_pos.x)*cell_size.w+hcx,
                        @intCast(i32, cur_pos.y)*cell_size.h+hcy,
                    );

                    break;
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

        var iter: usize = 0;
        while (grid[new_pos] == .snake) : (iter += 1) {
            if(iter == size) return; // loop board is full, give up
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

pub fn rect(renderer: *sdl.Renderer, r: sdl.Rectangle) !void {
    if (arena.wireframe) {
        try renderer.drawRect(r);
    } else {
        try renderer.fillRect(r);
    }
}


pub const win = .{.w = 800, .h = 800};

pub const Size = struct {
    w: i32,
    h: i32,
};

pub const Dir = enum{
    up,
    down,
    left,
    right
};

pub const Pos = struct {
    x: usize,
    y: usize,

    pub fn isEqual(a: *Pos, b: *Pos) bool {
        return a.x == b.x and a.y == b.y;
    }

    pub fn cycleDistance(a: *Pos, b: *Pos) isize {
        const order_a = @intCast(isize, arena.getPathOrder(a.x, a.y).*);
        const order_b = @intCast(isize, arena.getPathOrder(b.x, b.y).*);
        if (order_a < order_b) return order_b - order_a;
        
        return order_b - order_a + arena.size;
    }

    pub fn move(pos: Pos, dir: Dir) Pos {
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


pub const Snake = struct {
    body: std.ArrayList(Pos),
    dir: Dir = .right,

    pub fn move(snake: *Snake) !void {
        var slice = snake.body.items;
        var tail = slice[slice.len-1];

        var head = &slice[0];
        var prev = slice[0];

        head.* = head.move(snake.dir);

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

    pub fn draw(snake: *Snake, renderer: *sdl.Renderer) !void {
        const cell_size = arena.cell_size;
        const hcx = @divFloor(cell_size.w, 2);
        const hcy = @divFloor(cell_size.h, 2);

        // TODO: improve path rendering with the same method as snake rendering
        if (arena.render_path) {
            var cur_pos = snake.body.items[0];
            var base_pos = cur_pos;
            var prev_dir: Dir = undefined;

            try renderer.setColorRGBA(0xfc, 0x74, 0x19, 0xf5);

            while (!cur_pos.isEqual(&arena.apple)) {

                var tail = snake.body.items[snake.body.items.len-1];
                var ideal_dir = (try arena.getPath(cur_pos.x, cur_pos.y)).*;

                const dist_apple = cur_pos.cycleDistance(&arena.apple);
                const dist_tail = cur_pos.cycleDistance(&tail);
                var dist_next: isize = 1;
                var max_shortcut = @minimum(dist_apple, dist_tail-3);

                if (dist_apple < dist_tail) max_shortcut -= 1;

                if (snake.body.items.len > (arena.size*5)/8) max_shortcut = 0;
                if (max_shortcut > 0) {
                    for (std.enums.values(Dir)) |dir| {
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

                if (ideal_dir != prev_dir) {
                    try renderer.drawLine(
                        @intCast(i32, base_pos.x)*cell_size.w+hcx,
                        @intCast(i32, base_pos.y)*cell_size.h+hcy,
                        @intCast(i32, cur_pos.x)*cell_size.w+hcx,
                        @intCast(i32, cur_pos.y)*cell_size.h+hcy,
                    );

                    base_pos = cur_pos;
                    prev_dir = ideal_dir;
                }

                cur_pos = cur_pos.move(ideal_dir);
                if (cur_pos.isEqual(&arena.apple)) {
                    try renderer.drawLine(
                        @intCast(i32, base_pos.x)*cell_size.w+hcx,
                        @intCast(i32, base_pos.y)*cell_size.h+hcy,
                        @intCast(i32, cur_pos.x)*cell_size.w+hcx,
                        @intCast(i32, cur_pos.y)*cell_size.h+hcy,
                    );
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
        var cur_dir: Dir = undefined;

        var col = sdl.Color.rgb(0, 255, 0);

        var con_tail = false;

        for (snake.body.items) |_, i| {
            var seg = snake.body.items[i];

            try renderer.setColor(col);

            if (i != snake.body.items.len-1) {
                var next = snake.body.items[i+1];

                const diff_x = @intCast(isize, next.x) - @intCast(isize, seg.x);
                const diff_y = @intCast(isize, next.y) - @intCast(isize, seg.y);

                var dir_next: Dir = undefined;

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