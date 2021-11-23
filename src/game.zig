const sdl = @import("sdl2");
const std = @import("std");

const Actor = @import("actor.zig").Actor;

pub const abs = std.math.absInt;
pub const divC = std.math.divCeil;
pub const divF = std.math.divFloor;
pub const divT = std.math.divTrunc;

pub const win = .{.w = 800, .h = 800};

pub fn rect(wireframe: bool, renderer: *sdl.Renderer, r: sdl.Rectangle) !void {
    if (wireframe) try renderer.drawRect(r) else try renderer.fillRect(r);
}

// this will be used for the game board once I refactor to remove the arena namespace,
pub const Game = struct{
    pub const Config = struct{
        draw_wireframe: bool,
        draw_ai_data: bool,
    };

    pub const Board = struct{
        pub const State = enum{
            none,
            snake,
            food,
        };

        size: Size,
        grid: []State,
        food: Pos,

        pub fn cellPtr(self: *Board, x: i32, y: i32) error{OutOfBounds}!*State {
            if (x >= self.size.w) return error.OutOfBounds;
            if (y >= self.size.h) return error.OutOfBounds;
            return &self.grid[@intCast(usize, x+y*self.size.w)];
        }
    };

    cell_size: Size,
    alloc: *std.mem.Allocator,
    rand: std.rand.Random,
    snake: Snake,
    config: Config,
    board: Board,

    pub fn init(size: i32, ac: *std.mem.Allocator, r: *std.rand.Random, cfg: Config) !Game {
        var new_game = Game{
            .cell_size = .{.w = @divTrunc(win.w, size), .h = @divTrunc(win.h, size)},
            .alloc = ac,
            .rand = r,
            .snake = Snake{
                .body = try std.ArrayList(Pos).initCapacity(ac, @intCast(usize, size*size)),
            },
            .config = cfg,
            .board = Board{
                .size = Size{.w = size, .h = size},
                .grid = try ac.alloc(Board.State, @intCast(usize, size*size)),
                .food = Pos{.x=0, .y=0},
            },
        };
        try new_game.snake.body.append(.{.x = 0, .y = 0});
        new_game.board.grid[0] = .snake;
        new_game.newApple();

        return new_game;
    }

    pub fn reset(self: *Game) void {
        self.snake.body.shrinkRetainingCapacity(1);
        for (self.board.grid) |*cell| {
            cell.* = .none;
        }
        self.board.grid[0] = .snake;
        self.snake.body.items[0] = .{.x = 0, .y = 0};
        self.newApple();
    }

    pub fn deinit(self: *Game) void {
        self.alloc.free(self.board.grid);
        self.snake.body.deinit();
    }

    pub fn draw(self: *Game, renderer: *sdl.Renderer, act: *const Actor) !void {
        const cell_size = self.cell_size;
        { // draw apple
            try renderer.setColorRGB(0xf5, 0x00, 0x00);
            try rect(self.config.draw_wireframe, renderer, sdl.Rectangle{
                .x = self.board.food.x*cell_size.w+(try divC(i32, cell_size.w, 4)),
                .y = self.board.food.y*cell_size.h+(try divC(i32, cell_size.h, 4)),
                .width = try divC(i32, cell_size.w, 2),
                .height = try divC(i32, cell_size.h, 2),
            });
        }

        { // draw lines
            try renderer.setColorRGBA(127, 127, 127, 90);
            var c: i32 = 0;
            var r: i32 = 0;

            while (c < self.board.size.w+1) : (c += 1) {
                try renderer.drawLine(c*cell_size.w, 0, c*cell_size.w, win.h);
            }
            while (r < self.board.size.h+1) : (r += 1) {
                try renderer.drawLine(0, r*cell_size.h, win.w, r*cell_size.h);
            }
        }
        { // draw snake
            
            const hcx = @divFloor(cell_size.w, 2);
            const hcy = @divFloor(cell_size.h, 2);

            if (self.config.draw_ai_data) {
                try act.draw(renderer);

                var cur_pos = self.snake.body.items[0];
                var base_pos = cur_pos;
                var prev_dir: Dir = undefined;

                try renderer.setColorRGBA(0xfc, 0x74, 0x19, 0xf5);

                while (!cur_pos.isEqual(self.board.food)) {

                    const ideal_dir = act.dir(cur_pos);

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
                    if (cur_pos.isEqual(self.board.food)) {
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
            const fx = (try divT(i32, cell_size.w, 8));
            const fy = (try divT(i32, cell_size.h, 8));

            const cx = fx*6;
            const cy = fy*6;

            var prev: ?Pos = null;

            var cur_pos: Pos = self.snake.body.items[0];
            var cur_dir: Dir = undefined;

            var col = sdl.Color.rgb(0, 255, 0);

            var con_tail = false;

            for (self.snake.body.items) |_, i| {
                var seg = self.snake.body.items[i];

                try renderer.setColor(col);

                if (i != self.snake.body.items.len-1) {
                    var next = self.snake.body.items[i+1];

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

                    if (cur_dir != dir_next or i == self.snake.body.items.len-2) {

                        // incorporate tail into final segment                    
                        if (i == self.snake.body.items.len-2) {
                            if (cur_dir == dir_next) seg = self.snake.body.items[self.snake.body.items.len-1]
                            else con_tail=true;
                        }
                        
                        try rect(self.config.draw_wireframe, renderer, switch (cur_dir) {
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

                    try rect(self.config.draw_wireframe, renderer, .{
                        .x=fx+@intCast(i32, if(cur_dir==.right) cur_pos.x else seg.x)*cell_size.w,
                        .y=fy+@intCast(i32, if(cur_dir==.down) cur_pos.y else seg.y)*cell_size.h,
                        .width=cx+cell_size.w*h,
                        .height=cy+cell_size.h*v,
                    });
                }

                prev = seg;
            }
        }
    }

    pub fn newApple(self: *Game) void {
        var new_pos = self.rand.uintLessThan(usize, self.board.size.area());

        var left = self.rand.boolean();

        const orig = new_pos;

        var iter: usize = 0;
        while (self.board.grid[new_pos] == .snake) : (iter += 1) {
            if(iter == self.board.size.area()) return; // loop board is full, give up
            if (left) {
                if(new_pos == 0){left=false;new_pos=orig;}
                else new_pos -= 1;
            } else {
                if(new_pos == self.board.size.area()-1) {left=true;new_pos=orig;}
                else new_pos += 1;
            }
        }

        self.board.grid[new_pos] = .food;

        const n_i32 = @intCast(i32, new_pos);
        self.board.food = .{.x=@mod(n_i32, self.board.size.w), .y=@divTrunc(n_i32, self.board.size.h)};
    }

    pub fn step(self: *Game, act: *const Actor) !void {
        var slice = self.snake.body.items;
        var tail = slice[slice.len-1];

        var head = &slice[0];
        var prev = slice[0];

        head.* = head.move(act.dir(prev));

        for (slice[1..]) |*item| {
            std.mem.swap(Pos, item, &prev); // no more accidental pointer conundrums
        }

        // update grid with new cell head
        (try self.board.cellPtr(head.x, head.y)).* = .snake;

        if (head.isEqual(self.board.food)) { 
            try self.snake.body.append(tail);
            if (self.snake.body.items.len < self.board.size.area()) self.newApple();
        }
        else (try self.board.cellPtr(tail.x, tail.y)).* = .none; // remove the tail from the grid
    }
};

pub const Size = struct{
    w: i32,
    h: i32,

    pub fn area(self: Size) usize {
        return @intCast(usize, self.w*self.h);
    }
};


pub const Dir = enum{
    up,
    down,
    left,
    right
};

pub const Pos = struct {
    x: i32,
    y: i32,

    pub fn isEqual(a: Pos, b: Pos) bool {
        return a.x == b.x and a.y == b.y;
    }

    pub fn move(pos: Pos, dir: Dir) Pos {
        var p = pos;
        switch (dir) {
            .right => p.x += 1,
            .left => p.x -= 1,
            .up => p.y -= 1,
            .down => p.y += 1,
        }

        return p;
    }
};

pub const Snake = struct {
    body: std.ArrayList(Pos),
};