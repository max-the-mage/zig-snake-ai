// TODO: How the fuck does this work
// TODO: actually implement this

// ------------------------------------------------------------------------
// Agent: tree based
// ------------------------------------------------------------------------

// 1. Cell constraints means only 2 moves are possible instead of 4, see canMoveInTree,
// 2. Tree constrait means we can't move into a cell except from it's direct children
//    If the snake's tail is the root then
//     * moving to parent from child means retracing steps, this is always possible
//     * moving to unvisited cells is always possible
//     * moving to an exisiting child from a parent never happens.

const std = @import("std");
const Renderer = @import("sdl2").Renderer;

const act = @import("../actor.zig");
const Actor = act.Actor;

const g = @import("../game.zig");
const Pos = g.Pos;
const Dir = g.Dir;
const Game = g.Game;

const Self = @This();

game: *Game,
cell_parents: g.Grid(Pos),

pub fn init(game: *Game) !Self {
    return Self{
        .game = game,
        .cell_parents = undefined,
    };
}

pub fn deinit(_: *Self) void {}

pub fn actor(self: *Self) Actor {
    return Actor.init(self, dir, draw);
}

fn dir(s: *Self, p: Pos) Dir {
    if (p.x == 0 and p.y != s.game.board.size.h - 1) return .down;
    if (p.x == s.game.board.size.w - 1 and p.y != 0) return .up;
    if (p.y == 0 and p.x != 0) return .left;
    return .right;
}

fn draw(_: *Self, _: *Renderer) !void {
    return;
}

fn cellFromPos(p: Pos) Pos {
    return Pos{
        .x = @divTrunc(p.x, 2),
        .y = @divTrunc(p.y, 2),
    };
}

const unvisited = Pos{ .x = -1, .y = -1 };
const root = Pos{ .x = -2, .y = -2 };

fn cellTreeParents(s: *Self) !g.Grid(Pos) {
    var parents = g.Grid(Pos){
        .size = .{
            .w = @divTrunc(s.game.board.size.w, 2),
            .h = @divTrunc(s.game.board.size.h, 2),
        },
        .items = try s.game.alloc.alloc(Pos, @divTrunc(s.game.board.size.area(), 4)),
    };

    std.mem.set(Pos, parents.items, unvisited);

    var parent = root;

    for (s.game.snake.items) |_, i| {
        const c = s.game.snake.items[s.game.snake.items.len - (i + 1)];
        const cell_pos = cellFromPos(c);

        if ((try parents.cellPtr(cell_pos.x, cell_pos.y)).*.isEqual(unvisited)) {
            (try parents.cellPtr(cell_pos.x, cell_pos.y)).* = parent;
        }
        parent = cell_pos;
    }

    return parents;
}

fn canMoveInTree(s: *Self, a: Pos, b: Pos, d: Dir) bool {
    // condition 1
    if (!isCellMove(a, d)) return false;

    // condition 2 (only move to parent or unvisited);
    const cell_a = cellFromPos(a);
    const cell_b = cellFromPos(b);
    return cell_b.isEqual(cell_a) or
        (s.cell_parents.cellPtr(cell_b.x, cell_b.y) catch unreachable).*.isEqual(unvisited) or
        (s.cell_parents.cellPtr(cell_a.x, cell_a.y) catch unreachable).*.isEqual(cell_b);
}

fn moveToParent(s: *Self, p: Pos) Dir {
    const cell_p = cellFromPos(p);
    const parent = (s.cell_parents.cellPtr(cell_p.x, cell_p.y) catch unreachable).*;

    var x = @mod(p.x, 2);
    var y = @mod(p.y, 2);

    if (x == 1 and y == 0) return if (parent.y < cell_p.y) .up else .left;
    if (x == 0 and y == 1) return if (parent.y > cell_p.y) .down else .right;
    if (x == 0 and y == 0) return if (parent.x < cell_p.x) .left else .down;
    if (x == 1 and y == 1) return if (parent.x > cell_p.x) .right else .up;

    return .left;
}

fn isCellMove(p: Pos, d: Dir) bool {
    return cellFromPos(p).isEqual(cellFromPos(p.move(d)));
}

// TODO: Figure out how tf A* pathfinding works and use it here
// TODO: understand how the cell tree algorithm actually works so debugging this implementation is possible
