const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const BG_COLOR = r.Color{ .r = 10, .g = 10, .b = 10, .a = 255 };

const AUXIN_COLOR = r.RED;
const AUXIN_RADIUS = 15;
const AUXIN_DEATH_CIRCLE = 100;
const AUXIN_SPAWN_RATE = 10;
const MAX_AUXINS = 1000;

const SCREEN_WIDTH = 1280;
const SCREEN_HEIGHT = 960;

const Auxin = struct {
    position: r.Vector2,
};

fn genRandomPos() r.Vector2 {
    return r.Vector2{
        .x = @floatFromInt(r.GetRandomValue(0, SCREEN_WIDTH)),
        .y = @floatFromInt(r.GetRandomValue(0, SCREEN_HEIGHT)),
    };
}

fn genAuxins(auxins: *std.ArrayList(Auxin)) !void {
    for (0..AUXIN_SPAWN_RATE) |_| {
        const pos = genRandomPos();
        try auxins.appendBounded(Auxin{
            .position = pos,
        });
    }
}

fn killAuxins(auxins: *std.ArrayList(Auxin)) !void {
    var buf: [MAX_AUXINS]usize = undefined;
    var indices_to_remove = std.ArrayList(usize).initBuffer(&buf);
    for (auxins.items, 0..) |auxin_a, i| {
        for (auxins.items, 0..) |auxin_b, j| {
            if (i != j) {
                const dist = r.Vector2Distance(auxin_a.position, auxin_b.position);
                if (dist < AUXIN_DEATH_CIRCLE) {
                    try indices_to_remove.appendBounded(i);
                    break;
                }
            }
        }
    }

    var to_remove = indices_to_remove.items.len;
    while (to_remove > 0) : (to_remove -= 1) {
        const index = indices_to_remove.items[to_remove - 1];
        _ = auxins.swapRemove(index);
    }
}

pub fn main() !void {
    r.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Space Colonization Algorithm");
    defer r.CloseWindow();

    var buffer: [MAX_AUXINS]Auxin = undefined;
    var auxins = std.ArrayList(Auxin).initBuffer(&buffer);

    while (!r.WindowShouldClose()) {
        if (r.IsKeyPressed(r.KEY_SPACE)) {
            try genAuxins(&auxins);
            try killAuxins(&auxins);
        }

        r.BeginDrawing();
        r.ClearBackground(BG_COLOR);

        for (auxins.items) |auxin| {
            r.DrawCircleV(auxin.position, AUXIN_RADIUS, AUXIN_COLOR);
        }

        r.EndDrawing();
    }
}
