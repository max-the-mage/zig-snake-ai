// TODO: How the fuck does this work
// TODO: actually implement this

// ------------------------------------------------------------------------
// Agent: tree based
// ------------------------------------------------------------------------

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

fn cellFromPos(p: Pos) Pos {
    return Pos{
        .x=@divTrunc(p.x, 2),
        .y=@divTrunc(p.y, 2),
    };
}

fn cellTreeParents(s: *Self) !g.Grid(Pos) {
    var parents = g.Grid(Pos){
        .size = .{
            .w = @divTrunc(s.game.board.size.w, 2),
            .h = @divTrunc(s.game.board.size.h, 2),
        },
        .items = try s.game.alloc.alloc(Pos, @divTrunc(s.game.board.size.area(), 4)),
    };

    return parents;
}

fn isCellMove(p: Pos, d: Dir) bool {
    return cellFromPos(p).isEqual(cellFromPos(p.move(d)));
}
