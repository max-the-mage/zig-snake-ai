const std = @import("std");
const assert = std.debug.assert;
const meta = std.meta;
const trait = meta.trait;
const declInf = meta.declarationInfo;


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
        const child = ptr_info.Pointer.child;
        assert(ptr_info == .Pointer);
        assert(ptr_info.Pointer.size == .One);
        assert(@typeInfo(child) == .Struct);
        assert(trait.hasFn("init")(child));

        const init_args = @typeInfo(declInf(child, "init").data.Fn.fn_type).Fn.args;
        assert(init_args.len == 0 or init_args.len == 1);
        if (init_args.len == 1) {
            assert(init_args[0].arg_type.? == *std.mem.Allocator);
            assert(trait.hasFn("deinit")(child));
        }

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

fn getShorthand(comptime T: type) []const u8 {
    var base = @as([]const u8, "");

    for(@typeName(T)) |chr| {
        if (std.ascii.isUpper(chr)) base = base ++ [1]u8{std.ascii.toLower(chr)};
    }
    return base;
}

const impls = struct{
    pub const PerturbedHC = @import("actor/PerturbedHC.zig");
    pub const ZigZag = @import("actor/ZigZag.zig");
    pub const DynamicHCRepair = @import("actor/DynamicHCRepair.zig");
    pub const CellTree = @import("actor/CellTree.zig");
    pub const FixedRandom = @import("actor/FixedRandom.zig");
};
pub usingnamespace impls;

const decl_list = decls(impls);

const TypeInfo = std.builtin.TypeInfo;

pub const ActorTag = @Type(.{.Enum=.{
    .layout = .Auto,
    .tag_type = u32,
    .fields = blk: {
        var field_arr: [decl_list.len]TypeInfo.EnumField = undefined;

        inline for (decl_list) |decl, i| {
            field_arr[i] = TypeInfo.EnumField{
                .name = getShorthand(decl.data.Type),
                .value = i,
            };
        }

        break :blk &field_arr;
    },
    .decls = &[_]TypeInfo.Declaration{},
    .is_exhaustive = true,
}});

// TODO: fix this when @Type can resolve tagged unions
const ActorRef = union(enum) {temp};
pub const ActorType = type_blk: {
    var info = @typeInfo(ActorRef);
    info.Union.tag_type = ActorTag;
    info.Union.fields = blk: {
        var field_arr: [decl_list.len]TypeInfo.UnionField = undefined;

        inline for (decl_list) |decl, i| {
            field_arr[i] = TypeInfo.UnionField{
                .name = getShorthand(decl.data.Type),
                .field_type = decl.data.Type,
                .alignment = @alignOf(decl.data.Type),
            };
        }

        break :blk &field_arr;
    };

    break :type_blk @Type(info);
};