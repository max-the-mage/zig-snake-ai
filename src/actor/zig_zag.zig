// This is the actor for the perturbed hamiltonian cycle AI
// TODO: actually implement the interface

const std = @import("std");
const Renderer = @import("sdl2").Renderer;
const Rect = @import("sdl2").Rect;

const act = @import("../actor.zig");
const Actor = act.Actor;
const AnyActor = act.AnyActor;

const game = @import("../game.zig");
const Pos = game.Pos;
const Dir = game.Dir;
const arena = game.arena;

pub const ZigZag = struct {

    const Line = struct {
        x1: i32,
        y1: i32,
        x2: i32,
        y2: i32,
    };

    pub const Self = @This();

    path: []Dir,
    lines: std.ArrayList(Line),

    pub fn init(ac: *std.mem.Allocator) !ZigZag {
        var new = ZigZag{
            .path = try ac.alloc(Dir, arena.size),
            .lines = std.ArrayList(Line).init(ac),
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

        { // render
            const cell_size = arena.cell_size;

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
                if (cur_pos.isEqual(&goal)) {
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

    pub fn deinit(self: *Self, ac: *std.mem.Allocator) void {
        ac.free(self.path);
        self.lines.deinit();
    }

    pub fn actor(self: *Self) Actor {
        return Actor.init(self, zzDir, zzDraw);
    }

    fn zzDir(self: *Self, cur_head: Pos) Dir {
        var head = cur_head;
        var dir = (self.getPath(head.x, head.y) catch unreachable).*;

        return dir;
    }

    fn zzDraw(self: *Self, renderer: *Renderer) !void {

        if (arena.render_path) {
            try renderer.setColorRGBA(5, 252, 240, 90);

            for (self.lines.items) |line| {
                try renderer.drawLine(
                    line.x1, line.y1,
                    line.x2, line.y2,
                );
            }
        }
    }

    fn getPath(self: *@This(), x: usize, y: usize) error{OutOfBounds}!*Dir {
        if (x >= arena.w) return error.OutOfBounds;
        if (y >= arena.h) return error.OutOfBounds;
        return &self.path[x+y*arena.w];
    }
};