const std = @import("std");
const assert = std.debug.assert;

const Dir = @import("game.zig").Dir;
const Pos = @import("game.zig").Pos;
const Renderer = @import("sdl2").Renderer;

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

const decls = std.meta.declarations;

pub const ActorName = struct{
    Type: type,
    short: []const u8,
    long: []const u8,

    fn init(comptime T: type) ActorName {
        return .{
            .Type = T,
            .short = blk: {
                var base = @as([]const u8, "");

                for(@typeName(T)) |chr| {
                    if (std.ascii.isUpper(chr)) base = base ++ [1]u8{std.ascii.toLower(chr)};
                }
                break :blk base;
            },
            .long = @typeName(T),
        };
    }
};

const impls = struct{
    pub const PerturbedHC = @import("actor/PerturbedHC.zig");
    pub const ZigZag = @import("actor/ZigZag.zig");
    pub const DynamicHCRepair = @import("actor/DynamicHCRepair.zig");
    pub const CellTree = @import("actor/CellTree.zig");
    pub const FixedRandom = @import("actor/FixedRandom.zig");
};
pub usingnamespace impls;

const decl_list = decls(impls);
pub const actor_names: [decl_list.len]ActorName = blk: {
    var names: [decl_list.len]ActorName = undefined;

    inline for (decl_list) |decl, i| {
        names[i] = ActorName.init(decl.data.Type);
    }

    break :blk names;
};