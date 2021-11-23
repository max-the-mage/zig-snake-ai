// TODO: fixed but random hamiltonian cycle
// NOTE: maybe have a single actor "FixedCycle" that can choose from either a random path or a zigzag path.
// NOTE: FixedCycle will call a function to generate a random path. May be able to use this with phc as well
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
