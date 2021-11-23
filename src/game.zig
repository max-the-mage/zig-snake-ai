const sdl = @import("sdl2");
const std = @import("std");

const Actor = @import("actor.zig").Actor;

pub const abs = std.math.absInt;
pub const divC = std.math.divCeil;
pub const divF = std.math.divFloor;
pub const divT = std.math.divTrunc;

// TODO: this is terrible shared global state garbage, replace the arena with a "game" or "board" struct with a proper init function, can be passed to functions (paramaterize globals);
// TODO: move Pos, Dir, and Size to a new file
// TODO: replace u32 with i32 for sdl interop and to avoid them stupid @intCast calls

pub const arena = struct {
    pub var w: u32 = undefined;
    pub var h: u32 = undefined;
    pub var size: u32 = undefined;
    pub var cell_size = Size{.w = 0, .h = 0};
    pub var rand: *std.rand.Random = undefined;
    pub var snake = Snake{.body = undefined};

    pub var render_path = true;
    pub var wireframe = false;

    pub var benchmark: usize = undefined;

    pub const State = enum{
        none,
        snake,
        food,
    };

    pub var grid: []State = undefined;

    pub var apple: Pos = undefined;

    pub fn getCell(x: usize, y: usize) error{OutOfBounds}!*arena.State {
        if (x >= w) return error.OutOfBounds;
        if (y >= h) return error.OutOfBounds;
        return &grid[x+y*w];
    }

    pub fn draw(renderer: *sdl.Renderer) !void {

        try renderer.setColorRGB(0xf5, 0x00, 0x00);
        try rect(wireframe, renderer, sdl.Rectangle{
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

pub fn rect(wireframe: bool, renderer: *sdl.Renderer, r: sdl.Rectangle) !void {
    if (wireframe) {
        try renderer.drawRect(r);
    } else {
        try renderer.fillRect(r);
    }
}


pub const win = .{.w = 800, .h = 800};

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

        pub fn cellPtr(self: *Board, x: usize, y: usize) error{OutOfBounds}!*State {
            if (x >= self.size.w) return error.OutOfBounds;
            if (y >= self.size.h) return error.OutOfBounds;
            return &self.grid[x+y*self.size.w];
        }
    };

    cell_size: Size,
    alloc: *std.mem.Allocator,
    rand: *std.rand.Random,
    snake: Snake,
    config: Config,
    board: Board,

    pub fn init(size: i32, ac: *std.mem.Allocator, cfg: Config) !Game {
        var new_game = Game{
            .cell_size = .{.w = @divFloor(win.w, size), .h = @divFloor(win.h, size)},
            .alloc = ac,
            .rand = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())).random(),
            .snake = Snake{
                .body = std.ArrayList(Pos).initCapacity(ac, @intCast(usize, size*size)),
            },
            .config = cfg,
            .board = Board{
                .size = Size{.w = size, .h = size},
                .grid = ac.alloc(Board.State, size*size),
                .food = Pos{.x=0, .y=0},
            },
        };
        new_game.snake.body.items[0] = .{.x = 0, .y = 0};
        new_game.newApple();

        return new_game;
    }

    pub fn reset(self: *Game) void {
        self.snake.body.clearRetainingCapacity();
        for (self.board.grid) |*cell| {
            cell.* = .none;
        }
        self.snake.body.append(.{.x = 0, .y = 0});
        self.newApple();
    }

    pub fn deinit(self: *Game) void {
        self.alloc.free(self.board.grid);
        self.snake.body.deinit();
    }

    pub fn draw(self: *Game, renderer: *sdl.Renderer, act: *const Actor) !void {
        { // draw apple
            try renderer.setColorRGB(0xf5, 0x00, 0x00);
            try rect(self.config.draw_wireframe, renderer, sdl.Rectangle{
                .x = @intCast(i32, self.board.food)*self.board.size.w+(try divC(i32, self.board.size.w, 4)),
                .y = @intCast(i32, self.board.food)*self.board.size.h+(try divC(i32, self.board.size.h, 4)),
                .width = try divC(i32, self.board.size.w, 2),
                .height = try divC(i32, self.board.size.h, 2),
            });
        }

        { // draw lines
            try renderer.setColorRGBA(127, 127, 127, 90);
            var c: i32 = 0;
            var r: i32 = 0;

            while (c < self.board.size.w+1) : (c += 1) {
                try renderer.drawLine(c*self.board.size.w, 0, c*self.board.size.w, win.h);
            }
            while (r < self.board.size.h+1) : (r += 1) {
                try renderer.drawLine(0, r*self.board.size.h, win.w, r*self.board.size.h);
            }
        }
        { // draw snake
            const cell_size = self.cell_size;
            const hcx = @divFloor(cell_size.w, 2);
            const hcy = @divFloor(cell_size.h, 2);

            if (self.config.draw_ai_data.render_path) {
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
        var new_pos = self.rand.uintLessThan(usize, @as(usize,self.board.size.area()));

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

        self.board.apple = .{.x = new_pos % self.board.size.w, .y = new_pos/self.board.size.h};
    }

    pub fn step(self: *Game, act: *const Actor) void {
        var slice = self.snake.body.items;
        var tail = slice[slice.len-1];

        var head = &slice[0];
        var prev = slice[0];

        head.* = head.move(act.dir(prev));

        for (slice[1..]) |*item| {
            std.mem.swap(Pos, item, &prev); // no more accidental pointer conundrums
        }

        // update grid with new cell head
        (try self.board.celPtr(head.x, head.y)).* = .snake;

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

    pub fn area(self: Size) i32 {
        return self.w*self.h;
    }
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

    pub fn isEqual(a: Pos, b: Pos) bool {
        return a.x == b.x and a.y == b.y;
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

    pub fn move(snake: *Snake, dir: Dir) !void {
        var slice = snake.body.items;
        var tail = slice[slice.len-1];

        var head = &slice[0];
        var prev = slice[0];

        head.* = head.move(dir);

        for (slice[1..]) |*item| {
            std.mem.swap(Pos, item, &prev); // no more accidental pointer conundrums
        }

        // update grid with new cell head
        (try arena.getCell(head.x, head.y)).* = .snake;

        if (head.isEqual(arena.apple)) { 
            try snake.body.append(tail);
            if (snake.body.items.len < arena.size) arena.newApple();
        }
        else (try arena.getCell(tail.x, tail.y)).* = .none; // remove the tail from the grid
    }

    pub fn draw(snake: *Snake, renderer: *sdl.Renderer, actor: *const Actor) !void {
        const cell_size = arena.cell_size;
        const hcx = @divFloor(cell_size.w, 2);
        const hcy = @divFloor(cell_size.h, 2);

        if (arena.render_path) {
            try actor.draw(renderer);

            var cur_pos = snake.body.items[0];
            var base_pos = cur_pos;
            var prev_dir: Dir = undefined;

            try renderer.setColorRGBA(0xfc, 0x74, 0x19, 0xf5);

            while (!cur_pos.isEqual(arena.apple)) {

                const ideal_dir = actor.dir(cur_pos);

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
                if (cur_pos.isEqual(arena.apple)) {
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
                    
                    try rect(arena.wireframe, renderer, switch (cur_dir) {
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

                try rect(arena.wireframe, renderer, .{
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