const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const BG_COLOR = r.Color{ .r = 10, .g = 10, .b = 10, .a = 255 };
const RADIUS = 15;

const AUXIN_COLOR = r.PURPLE;
const AUXIN_RADIUS_3D = 3; // Smaller auxins for 3D
const AUXIN_DEATH_CIRCLE = 35;
const AUXIN_SPAWN_RATE = 15;
const MAX_AUXINS = 1000;

const NODE_COLOR = r.GREEN;
const BRANCH_COLOR = r.BROWN;
const CENTER_COLOR = r.YELLOW;

const SCREEN_WIDTH = 1280;
const SCREEN_HEIGHT = 960;

const BOUNDS_MIN = r.Vector3{ .x = -150, .y = -50, .z = -150 };
const BOUNDS_MAX = r.Vector3{ .x = 150, .y = 300, .z = 150 };

fn Auxin(comptime T: type) type {
    return struct {
        position: T,
    };
}

fn Node(comptime T: type) type {
    return struct {
        position: T,
        direction: T,
    };
}

fn genRandomPos(comptime T: type) T {
    switch (T) {
        r.Vector2 => return r.Vector2{
            .x = @floatFromInt(r.GetRandomValue(0, SCREEN_WIDTH)),
            .y = @floatFromInt(r.GetRandomValue(0, SCREEN_HEIGHT)),
        },
        r.Vector3 => {
            return r.Vector3{
                .x = @floatFromInt(r.GetRandomValue(@intFromFloat(BOUNDS_MIN.x), @intFromFloat(BOUNDS_MAX.x))),
                .y = @floatFromInt(r.GetRandomValue(@intFromFloat(BOUNDS_MIN.y), @intFromFloat(BOUNDS_MAX.y))),
                .z = @floatFromInt(r.GetRandomValue(@intFromFloat(BOUNDS_MIN.z), @intFromFloat(BOUNDS_MAX.z))),
            };
        },
        else => @compileError("Unsupported type"),
    }
}

fn genAuxins(comptime T: type, auxins: *std.ArrayList(Auxin(T))) !void {
    for (0..AUXIN_SPAWN_RATE) |_| {
        const pos = genRandomPos(T);
        try auxins.appendBounded(.{
            .position = pos,
        });
    }
}

fn killAuxins(comptime T: type, auxins: *std.ArrayList(Auxin(T)), nodes: *std.ArrayList(Node(T)), first_clear: bool) !void {
    var buf: [MAX_AUXINS]usize = undefined;
    var indices_to_remove = std.ArrayList(usize).initBuffer(&buf);

    if (first_clear) {
        for (auxins.items, 0..) |auxin_a, i| {
            for (auxins.items, 0..) |auxin_b, j| {
                if (i != j) {
                    const dist = switch (T) {
                        r.Vector2 => r.Vector2Distance(auxin_a.position, auxin_b.position),
                        r.Vector3 => r.Vector3Distance(auxin_a.position, auxin_b.position),
                        else => @compileError("Unsupported type"),
                    };

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
            const dist = switch (T) {
                r.Vector2 => r.Vector2Distance(auxin.position, node.position),
                r.Vector3 => r.Vector3Distance(auxin.position, node.position),
                else => @compileError("Unsupported type"),
            };
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

fn calculateGrowthDir(comptime T: type, auxins: *std.ArrayList(Auxin(T)), nodes: *std.ArrayList(Node(T))) !void {
    for (auxins.items) |auxin| {
        var closest_idx: usize = 0;
        var min_dist = std.math.floatMax(f32);

        for (nodes.items, 0..) |node, i| {
            const dist = switch (T) {
                r.Vector2 => r.Vector2Distance(auxin.position, node.position),
                r.Vector3 => r.Vector3Distance(auxin.position, node.position),
                else => @compileError("Unsupported type"),
            };
            if (dist < min_dist) {
                min_dist = dist;
                closest_idx = i;
            }
        }

        const new_dir = switch (T) {
            r.Vector2 => r.Vector2Add(nodes.items[closest_idx].direction, r.Vector2Subtract(auxin.position, nodes.items[closest_idx].position)),
            r.Vector3 => r.Vector3Add(nodes.items[closest_idx].direction, r.Vector3Subtract(auxin.position, nodes.items[closest_idx].position)),
            else => @compileError("Unsupported type"),
        };
        nodes.items[closest_idx].direction = new_dir;
    }

    for (nodes.items) |*node| {
        const len = switch (T) {
            r.Vector2 => r.Vector2Length(node.direction),
            r.Vector3 => r.Vector3Length(node.direction),
            else => @compileError("Unsupported type"),
        };
        if (len > 0) {
            const dir = switch (T) {
                r.Vector2 => r.Vector2Normalize(node.direction),
                r.Vector3 => r.Vector3Normalize(node.direction),
                else => @compileError("Unsupported type"),
            };
            node.direction = dir;
        }
    }
}

fn growNodes(comptime T: type, allocator: std.mem.Allocator, nodes: *std.ArrayList(Node(T))) !void {
    var new_nodes: std.ArrayList(Node(T)) = .empty;
    defer new_nodes.deinit(allocator);

    for (nodes.items) |node| {
        const len = switch (T) {
            r.Vector2 => r.Vector2Length(node.direction),
            r.Vector3 => r.Vector3Length(node.direction),
            else => @compileError("Unsupported type"),
        };

        if (len > 0) {
            const new_pos = switch (T) {
                r.Vector2 => r.Vector2Add(
                    node.position,
                    r.Vector2Scale(node.direction, RADIUS * 2),
                ),
                r.Vector3 => r.Vector3Add(
                    node.position,
                    r.Vector3Scale(node.direction, RADIUS * 3),
                ),
                else => @compileError("Unsupported type"),
            };
            try new_nodes.append(allocator, .{
                .position = new_pos,
                .direction = std.mem.zeroes(T),
            });
        }
    }

    for (new_nodes.items) |new_node| {
        try nodes.append(allocator, new_node);
    }
}

const Variant = enum {
    leaf,
    tree,
};

fn draw_leaf(arena: *std.heap.ArenaAllocator) !void {
    var aux_buf: [MAX_AUXINS]Auxin(r.Vector2) = undefined;
    var auxins = std.ArrayList(Auxin(r.Vector2)).initBuffer(&aux_buf);

    const node_alloc = arena.allocator();
    var nodes = std.ArrayList(Node(r.Vector2)).empty;
    try nodes.append(node_alloc, .{
        .position = genRandomPos(r.Vector2),
        .direction = r.Vector2{ .x = 0, .y = 0 },
    });

    while (!r.WindowShouldClose()) {
        if (r.IsKeyDown(r.KEY_SPACE)) {
            try genAuxins(r.Vector2, &auxins);
            try killAuxins(r.Vector2, &auxins, &nodes, true);
            try calculateGrowthDir(r.Vector2, &auxins, &nodes);
            try growNodes(r.Vector2, node_alloc, &nodes);
            try killAuxins(r.Vector2, &auxins, &nodes, false);
        }

        if (r.IsKeyPressed(r.KEY_R)) {
            auxins.clearRetainingCapacity();
            nodes.clearRetainingCapacity();
            try nodes.append(node_alloc, .{
                .position = genRandomPos(r.Vector2),
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

fn draw_tree(arena: *std.heap.ArenaAllocator) !void {
    var aux_buf: [MAX_AUXINS]Auxin(r.Vector3) = undefined;
    var auxins = std.ArrayList(Auxin(r.Vector3)).initBuffer(&aux_buf);

    const node_alloc = arena.allocator();
    var nodes = std.ArrayList(Node(r.Vector3)).empty;

    try nodes.append(node_alloc, .{
        .position = .{ .x = 0, .y = 0, .z = 0 },
        .direction = .{ .x = 0, .y = 0, .z = 0 },
    });

    var camera: r.Camera3D = undefined;
    camera.position = .{ .x = 250.0, .y = 150.0, .z = 250.0 };
    camera.target = .{ .x = 0.0, .y = 100.0, .z = 0.0 };
    camera.up = .{ .x = 0.0, .y = 1.0, .z = 0.0 };
    camera.fovy = 60.0;
    camera.projection = r.CAMERA_PERSPECTIVE;

    r.DisableCursor();

    const connection_dist = RADIUS * 3.5;
    const n_sides = 6;
    while (!r.WindowShouldClose()) {
        if (r.IsKeyDown(r.KEY_SPACE)) {
            try genAuxins(r.Vector3, &auxins);
            try killAuxins(r.Vector3, &auxins, &nodes, true);
            try calculateGrowthDir(r.Vector3, &auxins, &nodes);
            try growNodes(r.Vector3, node_alloc, &nodes);
            try killAuxins(r.Vector3, &auxins, &nodes, false);
        }

        if (r.IsKeyPressed(r.KEY_R)) {
            auxins.clearRetainingCapacity();
            nodes.clearRetainingCapacity();
            try nodes.append(node_alloc, .{
                .position = .{ .x = 0, .y = 0, .z = 0 },
                .direction = .{ .x = 0, .y = 0, .z = 0 },
            });
        }

        r.UpdateCamera(&camera, r.CAMERA_ORBITAL);

        r.BeginDrawing();
        {
            r.ClearBackground(BG_COLOR);

            r.BeginMode3D(camera);
            {
                r.DrawBoundingBox(
                    r.BoundingBox{ .min = BOUNDS_MIN, .max = BOUNDS_MAX },
                    r.DARKGRAY,
                );

                for (auxins.items) |auxin| {
                    r.DrawSphere(auxin.position, AUXIN_RADIUS_3D, AUXIN_COLOR);
                }

                for (nodes.items, 0..) |node_a, i| {
                    for (nodes.items[i + 1 ..]) |node_b| {
                        const dist = r.Vector3Distance(node_a.position, node_b.position);
                        if (dist > 0.1 and dist < connection_dist) {
                            const radius = @as(f32, RADIUS) * 0.3;
                            r.DrawCylinderEx(node_a.position, node_b.position, radius, radius, n_sides, BRANCH_COLOR);
                        }
                    }
                }
            }
            r.EndMode3D();
        }

        r.EndDrawing();
    }
}

pub fn main() !void {
    var arg_iter = std.process.args();
    _ = arg_iter.next(); // skip program name

    const variant = std.meta.stringToEnum(Variant, (arg_iter.next() orelse "leaf")) orelse Variant.leaf;

    r.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Space Colonization Algorithm");
    defer r.CloseWindow();
    r.SetTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    switch (variant) {
        .leaf => try draw_leaf(&arena),
        .tree => try draw_tree(&arena),
    }
}
