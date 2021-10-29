const std = @import("std");
const sdl = @import("sdl2");

const arena = struct {
    const width: u32 = 14;
    const height: u32 = 14;
    const size: u32 = width*height;
};

const BoardState = enum {
    Empty,
    Snake,
    Food,
};

const grid_size = 21;
const w = 30;
const s = 1280/2 - (grid_size*w)/2;

var snake_board = [_]BoardState{BoardState.Empty}**(w*w);

fn getCell(x: usize, y: usize) *BoardState {
    return &snake_board[x+y*w];
}

fn tourNum(x: u32, y: u32) u32 {
    return x+y;
}

pub fn main() !void {
    try sdl.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer sdl.quit();

    var window = try sdl.createWindow(
        "sdl2 Wrapper Demo",
        .{ .centered = {} }, .{ .centered = {} },
        1280, 720,
        .{ .shown = true },
    );
    defer window.destroy();
    
    var renderer = try sdl.createRenderer(window, null, .{ .accelerated = true, .present_vsync = true });
    defer renderer.destroy();

    var cur: usize = 0;
    var prev: usize = 0;
    var frame: usize = 0;

    mainLoop: while (true) {
        while (sdl.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainLoop,
                else => {},
            }
        }

        if (@mod(frame, 1) == 0) {
            snake_board[prev] = .Empty;

            if (cur > (w*w)-1) cur = 0;
            snake_board[cur] = .Snake;

            snake_board[(w*w-1)-prev] = .Empty;
            snake_board[(w*w-1)-cur] = .Food;
            
            prev = cur;
            cur += 1;
        }
        frame += 1;

        
        try renderer.setColorRGB(127, 127, 127);
        try renderer.clear();
        
        var x: i32 = 0;
        var y: i32 = 0;

        while (y < w) : (y += 1) {
            x = 0;
            while(x < w) : (x += 1) {
                var cell = getCell(@intCast(usize, x), @intCast(usize, y));

                try switch (cell.*) {
                    .Empty => renderer.setColorRGB(0xff, 0xff, 0xff),
                    .Snake => renderer.setColorRGB(0x00, 0xf5, 0x00),
                    .Food => renderer.setColorRGB(0xf5, 0x00, 0x00),
                };
                try renderer.fillRect(sdl.Rectangle{
                    .x = s+x*grid_size,
                    .y = 20+y*grid_size,
                    .width = @intCast(i32, grid_size),
                    .height = @intCast(i32, grid_size),
                });
            }
        }

        try renderer.setColorRGB(0, 0, 0);
        var c: i32 = 0;
        var r: i32 = 0;

        while (c < w+1) : (c += 1) {
            try renderer.drawLine(s+c*grid_size, 20, s+c*grid_size, 20+grid_size*w);
        }
        while (r < w+1) : (r += 1) {
            try renderer.drawLine(s, 20+r*grid_size, s+grid_size*w, 20+r*grid_size);
        }

        renderer.present();
    }
}
