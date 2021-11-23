// This is the actor for the perturbed hamiltonian cycle AI

const std = @import("std");
const Renderer = @import("sdl2").Renderer;

const act = @import("../actor.zig");
const Actor = act.Actor;
const AnyActor = act.AnyActor;

const g = @import("../game.zig");
const Pos = g.Pos;
const Dir = g.Dir;
const Game = g.Game;

const Self = @This();

path: []Dir,
path_order: []isize,
game: *Game,

pub fn init(game: *Game) !Self {
    var new = Self{
        .path = try game.alloc.alloc(Dir, game.board.size.area()),
        .path_order = try game.alloc.alloc(isize, game.board.size.area()),
        .game = game,
    };

    // create simple hamilton path
    // note: this code only works on evenly sized grids
    var i: i32  = 0;
    while (i < game.board.size.w) : (i+= 1) {
        (try new.getPath(i, 0)).* = .left; // line across top row
        (try new.getPath(i, game.board.size.h-1)).* = if (@mod(i, 2)==0) .right else .up; // bottom zigzags

        // lines up and down
        var j: i32 = 1;
        while(j < game.board.size.h-1) : (j+=1) {
            (try new.getPath(i, j)).* = if (@mod(i, 2)==0) .down else .up;
        }

        if (i > 0 and i < game.board.size.w-1) { // top zigzags
            (try new.getPath(i, 1)).* = if (@mod(i, 2)==0) .down else .right;
        }
    }
    (try new.getPath(0, 0)).* = .down; // top left corner

    { // cycle ordering for skips
        var cur_pos = Pos{.x=0, .y=0};
        var ordering: isize = 0;
        while (ordering < game.board.size.area()) : (ordering += 1) {
            new.getPathOrder(cur_pos.x, cur_pos.y).* = ordering;
            cur_pos = cur_pos.move((try new.getPath(cur_pos.x, cur_pos.y)).*);
        }
    }

    return new;
}

pub fn deinit(self: *Self) void {
    self.game.alloc.free(self.path);
    self.game.alloc.free(self.path_order);
}

pub fn actor(self: *Self) Actor {
    return Actor.init(self, phcDir, phcDraw);
}

fn phcDir(self: *Self, cur_head: Pos) Dir {

    var snake = &self.game.snake;

    var head = cur_head;
    var tail = snake.body.items[snake.body.items.len-1];
    var dir = (self.getPath(head.x, head.y) catch unreachable).*;

    const dist_apple = self.cycleDistance(&head, &self.game.board.food);
    const dist_tail = self.cycleDistance(&head, &tail);
    var dist_next: isize = 1;
    var max_shortcut = @minimum(dist_apple, dist_tail-3);

    if (dist_apple < dist_tail) max_shortcut -= 1;

    if (snake.body.items.len > (self.game.board.size.area()*5)/8) max_shortcut = 0; // just follow the path when the board is mostly filled
    if (max_shortcut > 0) {

        // zig coming in clutch with fancy meta stuff
        for (std.enums.values(Dir)) |new_dir| {
            var b = head.move(new_dir);

            if(b.x < 0 or b.y < 0) continue;

            if ((self.game.board.cellPtr(b.x, b.y) catch &Game.Board.State.snake).* != .snake) {
                const dist_b = self.cycleDistance(&head, &b);
                if (dist_b <= max_shortcut and dist_b > dist_next) {
                    dir = new_dir;
                    dist_next = dist_b;
                }
            }
        }
    }

    return dir;
}

fn phcDraw(self: *Self, renderer: *Renderer) !void {

    if (self.game.config.draw_ai_data) {
        try renderer.setColorRGBA(5, 252, 240, 90);

        const cell_size = self.game.cell_size;

        const hcx = @divFloor(cell_size.w, 2);
        const hcy = @divFloor(cell_size.h, 2);

        var cur_pos: Pos = .{.x=0, .y=0};
        var base_pos: Pos = cur_pos;
        var prev_dir: Dir = self.path[0];

        var goal: Pos = .{.x=0, .y=0};

        while (true) {
            const new_dir = (try self.getPath(cur_pos.x, cur_pos.y)).*;

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
            if (cur_pos.isEqual(goal)) {
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
}

fn getPath(self: *@This(), x: i32, y: i32) error{OutOfBounds}!*Dir {
    if (x >= self.game.board.size.w) return error.OutOfBounds;
    if (y >= self.game.board.size.h) return error.OutOfBounds;
    return &self.path[@intCast(usize, x+y*self.game.board.size.w)];
}

fn getPathOrder(self: *@This(), x: i32, y: i32) *isize {
    // if (x >= w) return error.OutOfBounds;
    // if (y >= h) return error.OutOfBounds;
    return &self.path_order[@intCast(usize, x+y*self.game.board.size.w)];
}

fn cycleDistance(self: *@This(), a: *Pos, b: *Pos) isize {
    const order_a = @intCast(isize, self.getPathOrder(a.x, a.y).*);
    const order_b = @intCast(isize, self.getPathOrder(b.x, b.y).*);
    if (order_a < order_b) return order_b - order_a;
    
    return order_b - order_a + @intCast(isize, self.game.board.size.area());
}