const Dir = @import("game.zig").Dir;
const Pos = @import("game.zig").Pos;
const Renderer = @import("sdl2").Renderer;

pub const Actor = struct {
    impl: *c_void,

    dirFn: fn (*c_void, Pos) Dir,
    drawFn: fn (*c_void, *Renderer) anyerror!void,

    pub fn dir(iface: *const Actor, h: Pos) Dir {
        return iface.dirFn(iface.impl, h);
    }

    pub fn draw(iface: *const Actor, r: *Renderer) anyerror!void {
        return iface.drawFn(iface.impl, r);
    }
};

pub const PerturbedHC = @import("actor/phc.zig").PerturbedHC;