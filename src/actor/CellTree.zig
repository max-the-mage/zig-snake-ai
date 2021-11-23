// TODO: How the fuck does this work
// TODO: actually implement this

const Renderer = @import("sdl2").Renderer;

const act = @import("../actor.zig");
const Actor = act.Actor;

const g = @import("../game.zig");
const Pos = g.Pos;
const Dir = g.Dir;
const Game = g.Game;

const Self = @This();

game: *Game,

pub fn init(game: *Game) !Self {
    return Self{.game = game};
}
pub fn deinit(_: *Self) void {}

pub fn actor(self: *Self) Actor {
    return Actor.init(self, dir, draw);
}

fn dir(s: *Self, p: Pos) Dir {
    if (p.x == 0 and p.y != s.game.board.size.h-1) return .down;
    if (p.x == s.game.board.size.w-1 and p.y != 0) return .up;
    if (p.y == 0 and p.x != 0) return .left;
    return .right;
}

fn draw(_: *Self, _: *Renderer) !void {
    
    return;
}
