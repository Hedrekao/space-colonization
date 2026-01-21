const std = @import("std");
const r = @cImport(
    @cInclude("raylib.h"),
);

const BG_COLOR = r.Color{ .r = 10, .g = 10, .b = 10, .a = 255 };

pub fn main() !void {
    r.InitWindow(1280, 960, "Space Colonization Algorithm");
    defer r.CloseWindow();

    while (!r.WindowShouldClose()) {
        r.BeginDrawing();
        r.ClearBackground(BG_COLOR);
        r.EndDrawing();
    }
}
