const Dir = @import("game.zig").Dir;
const Pos = @import("game.zig").Pos;
const Renderer = @import("sdl2").Renderer;

const assert = @import("std").debug.assert;

pub const AnyActor = opaque {};
pub const Actor = struct {
    impl: *AnyActor,
    dirFn: fn (*AnyActor, Pos) Dir,
    drawFn: fn (*AnyActor, *Renderer) anyerror!void,

    pub fn init(
        pointer: anytype, 
        comptime dirFn: fn (@TypeOf(pointer), Pos) Dir, 
        comptime drawFn: fn (@TypeOf(pointer), *Renderer) anyerror!void
    ) Actor {
        const Ptr = @TypeOf(pointer);
        const ptr_info = @typeInfo(Ptr);
        assert(ptr_info == .Pointer);
        assert(ptr_info.Pointer.size == .One);
        assert(@typeInfo(ptr_info.Pointer.child) == .Struct);
        const gen = struct {
            const alignment = ptr_info.Pointer.alignment;
            
            fn dir(ptr: *AnyActor, p: Pos) Dir {
                const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
                return dirFn(self, p);
            }

            fn draw(ptr: *AnyActor, r: *Renderer) anyerror!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
                return drawFn(self, r);
            }
        };

        return .{
            .impl = @ptrCast(*AnyActor, pointer),
            .dirFn = gen.dir,
            .drawFn = gen.draw,
        };
    }

    pub fn dir(iface: *const Actor, h: Pos) Dir {
        return iface.dirFn(iface.impl, h);
    }

    pub fn draw(iface: *const Actor, r: *Renderer) anyerror!void {
        return iface.drawFn(iface.impl, r);
    }
};

pub const PerturbedHC = @import("actor/PerturbedHC.zig");
pub const ZigZag = @import("actor/ZigZag.zig");
pub const DynamicHCRepair = @import("actor/DynamicHCRepair.zig");