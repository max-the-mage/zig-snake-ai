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

fn dir(_: *Self, _: Pos) Dir {
    return .right;
}

fn draw(_: *Self, _: *Renderer) !void {
    
    return;
}
