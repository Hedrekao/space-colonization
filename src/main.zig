const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const BG_COLOR = r.Color{ .r = 10, .g = 10, .b = 10, .a = 255 };
const RADIUS = 15;

const AUXIN_COLOR = r.PURPLE;
const AUXIN_DEATH_CIRCLE = 35;
const AUXIN_SPAWN_RATE = 10;
const MAX_AUXINS = 1000;

const NODE_COLOR = r.GREEN;
const CENTER_COLOR = r.YELLOW;

const SCREEN_WIDTH = 1280;
const SCREEN_HEIGHT = 960;

const Auxin = struct {
    position: r.Vector2,
};

const Node = struct {
    position: r.Vector2,
    direction: r.Vector2,
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

fn killAuxins(auxins: *std.ArrayList(Auxin), nodes: *std.ArrayList(Node), first_clear: bool) !void {
    var buf: [MAX_AUXINS]usize = undefined;
    var indices_to_remove = std.ArrayList(usize).initBuffer(&buf);

    if (first_clear) {
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

        indices_to_remove.clearRetainingCapacity();
    }

    for (auxins.items, 0..) |auxin, i| {
        for (nodes.items) |node| {
            const dist = r.Vector2Distance(auxin.position, node.position);
            if (dist < AUXIN_DEATH_CIRCLE) {
                try indices_to_remove.appendBounded(i);
                break;
            }
        }
    }

    var to_remove = indices_to_remove.items.len;
    while (to_remove > 0) : (to_remove -= 1) {
        const index = indices_to_remove.items[to_remove - 1];
        _ = auxins.swapRemove(index);
    }
}

fn calculateGrowthDir(auxins: *std.ArrayList(Auxin), nodes: *std.ArrayList(Node)) !void {
    for (auxins.items) |auxin| {
        var closest_idx: usize = 0;
        var min_dist = std.math.floatMax(f32);

        for (nodes.items, 0..) |node, i| {
            const dist = r.Vector2Distance(auxin.position, node.position);
            if (dist < min_dist) {
                min_dist = dist;
                closest_idx = i;
            }
        }

        nodes.items[closest_idx].direction = r.Vector2Add(
            nodes.items[closest_idx].direction,
            r.Vector2Subtract(auxin.position, nodes.items[closest_idx].position),
        );
    }

    for (nodes.items) |*node| {
        if (r.Vector2Length(node.direction) > 0) {
            node.direction = r.Vector2Normalize(node.direction);
        }
    }
}

fn growNodes(allocator: std.mem.Allocator, nodes: *std.ArrayList(Node)) !void {
    var new_nodes: std.ArrayList(Node) = std.ArrayList(Node).empty;
    defer new_nodes.deinit(allocator);

    for (nodes.items) |node| {
        if (r.Vector2Length(node.direction) > 0) {
            const new_pos = r.Vector2Add(
                node.position,
                r.Vector2Scale(node.direction, RADIUS * 2),
            );
            try new_nodes.append(allocator, .{
                .position = new_pos,
                .direction = r.Vector2{ .x = 0, .y = 0 },
            });
        }
    }

    for (new_nodes.items) |new_node| {
        try nodes.append(allocator, new_node);
    }
}

pub fn main() !void {
    r.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Space Colonization Algorithm");
    defer r.CloseWindow();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var aux_buf: [MAX_AUXINS]Auxin = undefined;
    var auxins = std.ArrayList(Auxin).initBuffer(&aux_buf);

    const node_alloc = arena.allocator();
    var nodes = std.ArrayList(Node).empty;
    try nodes.append(node_alloc, .{
        .position = genRandomPos(),
        .direction = r.Vector2{ .x = 0, .y = 0 },
    });

    r.SetTargetFPS(60);

    while (!r.WindowShouldClose()) {
        if (r.IsKeyDown(r.KEY_SPACE)) {
            try genAuxins(&auxins);
            try killAuxins(&auxins, &nodes, true);
            try calculateGrowthDir(&auxins, &nodes);
            try growNodes(node_alloc, &nodes);
            try killAuxins(&auxins, &nodes, false);
        }

        if (r.IsKeyPressed(r.KEY_R)) {
            auxins.clearRetainingCapacity();
            nodes.clearRetainingCapacity();
            try nodes.append(node_alloc, .{
                .position = genRandomPos(),
                .direction = r.Vector2{ .x = 0, .y = 0 },
            });
        }

        r.BeginDrawing();
        r.ClearBackground(BG_COLOR);

        for (auxins.items) |auxin| {
            r.DrawCircleV(auxin.position, RADIUS, AUXIN_COLOR);
        }

        for (nodes.items) |node| {
            r.DrawCircleV(node.position, RADIUS, NODE_COLOR);
            r.DrawCircleV(node.position, RADIUS / 5, CENTER_COLOR);
        }

        r.EndDrawing();
    }
}
