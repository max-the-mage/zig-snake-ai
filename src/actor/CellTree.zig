// TODO: How the fuck does this work
// TODO: actually implement this

const Renderer = @import("sdl2").Renderer;

const act = @import("../actor.zig");
const Actor = act.Actor;

const game = @import("../game.zig");
const Pos = game.Pos;
const Dir = game.Dir;

const Self = @This();

a: i32,

pub fn init() Self {
    return Self{.a = 0};
}

pub fn actor(self: *Self) Actor {
    return Actor.init(self, dir, draw);
}

fn dir(_: *Self, _: Pos) Dir {
    return .right;
}

fn draw(_: *Self, _: *Renderer) !void {
    
    return;
}
