// This is the actor for the perturbed hamiltonian cycle AI

const std = @import("std");
const Renderer = @import("sdl2").Renderer;

const act = @import("../actor.zig");
const Actor = act.Actor;
const AnyActor = act.AnyActor;

const game = @import("../game.zig");
const Pos = game.Pos;
const Dir = game.Dir;
const arena = game.arena;

const Self = @This();

path: []game.Dir,
path_order: []usize,

pub fn init(ac: *std.mem.Allocator) !Self {
    var new = Self{
        .path = try ac.alloc(game.Dir, arena.size),
        .path_order = try ac.alloc(usize, arena.size),
    };

    // create simple hamilton path
    // note: this code only works on evenly sized grids
    var i: usize  = 0;
    while (i < arena.w) : (i+= 1) {
        (try new.getPath(i, 0)).* = .left; // line across top row
        (try new.getPath(i, arena.h-1)).* = if (i%2==0) .right else .up; // bottom zigzags

        // lines up and down
        var j: usize = 1;
        while(j < arena.h-1) : (j+=1) {
            (try new.getPath(i, j)).* = if (i%2==0) .down else .up;
        }

        if (i > 0 and i < arena.w-1) { // top zigzags
            (try new.getPath(i, 1)).* = if (i%2==0) .down else .right;
        }
    }
    (try new.getPath(0, 0)).* = .down; // top left corner

    { // cycle ordering for skips
        var cur_pos = Pos{.x=0, .y=0};
        var ordering: usize = 0;
        while (ordering < arena.size) : (ordering += 1) {
            new.getPathOrder(cur_pos.x, cur_pos.y).* = ordering;
            cur_pos = cur_pos.move((try new.getPath(cur_pos.x, cur_pos.y)).*);
        }
    }

    return new;
}

pub fn deinit(self: *Self, ac: *std.mem.Allocator) void {
    ac.free(self.path);
    ac.free(self.path_order);
}

pub fn actor(self: *Self) Actor {
    return Actor.init(self, phcDir, phcDraw);
}

fn phcDir(self: *Self, cur_head: Pos) Dir {

    var snake = &arena.snake;

    var head = cur_head;
    var tail = snake.body.items[snake.body.items.len-1];
    var dir = (self.getPath(head.x, head.y) catch unreachable).*;

    const dist_apple = self.cycleDistance(&head, &arena.apple);
    const dist_tail = self.cycleDistance(&head, &tail);
    var dist_next: isize = 1;
    var max_shortcut = @minimum(dist_apple, dist_tail-3);

    if (dist_apple < dist_tail) max_shortcut -= 1;

    if (snake.body.items.len > (arena.size*5)/8) max_shortcut = 0; // just follow the path when the board is mostly filled
    if (max_shortcut > 0) {

        // zig coming in clutch with fancy meta stuff
        for (std.enums.values(Dir)) |new_dir| {
            var b = head.move(new_dir);

            if ((arena.getCell(b.x, b.y) catch &arena.State.snake).* != .snake) {
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

    if (arena.render_path) {
        try renderer.setColorRGBA(5, 252, 240, 90);

        const cell_size = arena.cell_size;

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
}

fn getPath(self: *@This(), x: usize, y: usize) error{OutOfBounds}!*Dir {
    if (x >= arena.w) return error.OutOfBounds;
    if (y >= arena.h) return error.OutOfBounds;
    return &self.path[x+y*arena.w];
}

fn getPathOrder(self: *@This(), x: usize, y: usize) *usize {
    // if (x >= w) return error.OutOfBounds;
    // if (y >= h) return error.OutOfBounds;
    return &self.path_order[x+y*arena.w];
}

fn cycleDistance(self: *@This(), a: *Pos, b: *Pos) isize {
    const order_a = @intCast(isize, self.getPathOrder(a.x, a.y).*);
    const order_b = @intCast(isize, self.getPathOrder(b.x, b.y).*);
    if (order_a < order_b) return order_b - order_a;
    
    return order_b - order_a + arena.size;
}