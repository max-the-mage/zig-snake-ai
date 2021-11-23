// This is the actor for the perturbed hamiltonian cycle AI
// TODO: actually implement the interface

const std = @import("std");
const Renderer = @import("sdl2").Renderer;
const Rect = @import("sdl2").Rectangle;

const act = @import("../actor.zig");
const Actor = act.Actor;

const g = @import("../game.zig");
const Game = g.Game;
const Pos = g.Pos;
const Dir = g.Dir;

const Line = struct {
    x1: i32,
    y1: i32,
    x2: i32,
    y2: i32,
};

const Self = @This();

path: []Dir,
lines: std.ArrayList(Line),
game: *Game,

pub fn init(game: *Game) !Self {
    var new = Self{
        .path = try game.alloc.alloc(Dir, game.board.size.area()),
        .lines = std.ArrayList(Line).init(game.alloc),
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

    { // create lines to render
        const cell_size = game.cell_size;

        const hcx = @divFloor(cell_size.w, 2);
        const hcy = @divFloor(cell_size.h, 2);

        var cur_pos: Pos = .{.x=0, .y=0};
        var base_pos: Pos = cur_pos;
        var prev_dir: Dir = new.path[0];

        var goal: Pos = .{.x=0, .y=0};

        while (true) {
            const new_dir = (try new.getPath(cur_pos.x, cur_pos.y)).*;

            if (new_dir != prev_dir) {
                try new.lines.append(.{
                    .x1=@intCast(i32, base_pos.x)*cell_size.w+hcx,
                    .y1=@intCast(i32, base_pos.y)*cell_size.h+hcy,
                    .x2=@intCast(i32, cur_pos.x)*cell_size.w+hcx,
                    .y2=@intCast(i32, cur_pos.y)*cell_size.h+hcy,
                });

                prev_dir = new_dir;
                base_pos = cur_pos;
            }

            cur_pos = cur_pos.move(new_dir);
            if (cur_pos.isEqual(goal)) {
                try new.lines.append(.{
                    .x1=@intCast(i32, base_pos.x)*cell_size.w+hcx,
                    .y1=@intCast(i32, base_pos.y)*cell_size.h+hcy,
                    .x2=@intCast(i32, cur_pos.x)*cell_size.w+hcx,
                    .y2=@intCast(i32, cur_pos.y)*cell_size.h+hcy,
                });

                break;
            }
        }
    }

    return new;
}

pub fn deinit(self: *Self) void {
    self.game.alloc.free(self.path);
    self.lines.deinit();
}

pub fn actor(self: *Self) Actor {
    return Actor.init(self, dir, draw);
}

fn dir(self: *Self, cur_head: Pos) Dir {
    return (self.getPath(cur_head.x, cur_head.y) catch unreachable).*;
}

fn draw(self: *Self, renderer: *Renderer) !void {

    if (self.game.config.draw_ai_data) {
        try renderer.setColorRGBA(5, 252, 240, 90);

        for (self.lines.items) |line| {
            try renderer.drawLine(
                line.x1, line.y1,
                line.x2, line.y2,
            );
        }
    }
}

fn getPath(self: *@This(), x: i32, y: i32) error{OutOfBounds}!*Dir {
    if (x >= self.game.board.size.w) return error.OutOfBounds;
    if (y >= self.game.board.size.h) return error.OutOfBounds;
    return &self.path[@intCast(usize, x+y*self.game.board.size.w)];
}