const std = @import("std");

const Point = struct {
    i: usize,
    j: usize,

    pub fn add_dij(self: *const Point, di: i32, dj: i32) ?Point {
        const i_: i32 = @intCast(self.i);
        const j_: i32 = @intCast(self.j);

        if (i_ + di >= 0 and j_ + dj >= 0) {
            return Point{
                .i = @intCast(i_ + di),
                .j = @intCast(j_ + dj),
            };
        }

        return null;
    }
};

const Board = struct {
    grid: std.ArrayList([]const u8),

    pub fn find_dragon(self: *const Board) Point {
        for (self.grid.items, 0..) |row, i| {
            for (row, 0..) |cell, j| {
                if (cell == 'D') {
                    return Point{ .i = i, .j = j };
                }
            }
        }

        unreachable;
    }

    pub fn is_valid(self: *const Board, p: Point) bool {
        return p.i >= 0 and p.i < self.rows() and p.j >= 0 and p.j < self.cols();
    }

    pub fn is_sheep(self: *const Board, p: Point) bool {
        std.debug.assert(self.is_valid(p));

        return self.grid.items[p.i][p.j] == 'S';
    }

    pub fn is_hideout(self: *const Board, p: Point) bool {
        std.debug.assert(self.is_valid(p));

        return self.grid.items[p.i][p.j] == '#';
    }

    pub fn rows(self: *const Board) usize {
        return self.grid.items.len;
    }

    pub fn cols(self: *const Board) usize {
        std.debug.assert(self.grid.items.len > 0);

        return self.grid.items[0].len;
    }

    pub fn raw(self: *const Board, p: Point) usize {
        return p.i * self.cols() + p.j;
    }

    pub fn deinit(self: *Board, allocator: std.mem.Allocator) void {
        self.grid.deinit(allocator);
    }
};

const Input = struct {
    file_content: []const u8,
    board: Board,

    pub fn parse(allocator: std.mem.Allocator, file_path: []const u8) !Input {
        return Input.init(allocator, file_path);
    }

    fn init(allocator: std.mem.Allocator, file_path: []const u8) !Input {
        const file_content = try std.fs.cwd().readFileAlloc(
            file_path,
            allocator,
            .unlimited,
        );
        errdefer allocator.free(file_content);

        var grid: std.ArrayList([]const u8) = .empty;
        errdefer grid.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |line| {
            try grid.append(allocator, line);
        }

        return Input{
            .file_content = file_content,
            .board = Board{ .grid = grid },
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.board.deinit(allocator);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        @panic("Wrong input. I do not care .. Use `help`");
    }

    const part = try std.fmt.parseInt(u8, args[1], 10);
    const file_path = args[2];
    std.debug.print("- Running part {} ...\n", .{part});
    std.debug.print("- Input file: {s}\n", .{file_path});

    var input = try Input.parse(allocator, file_path);
    defer input.deinit(allocator);

    const answer = try switch (part) {
        1 => solve_1(allocator, input, 4),
        2 => solve_2(allocator, input, 20),
        3 => solve_3(allocator, input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

const Moves_I = [_]i32{ -2, -2, -1, -1, 1, 1, 2, 2 };
const Moves_J = [_]i32{ -1, 1, -2, 2, -2, 2, -1, 1 };

const PqType = struct {
    priority: usize,
    p: Point,
};

const Pq = std.PriorityQueue(PqType, void, struct {
    pub fn cmp(_: void, a: PqType, b: PqType) std.math.Order {
        if (a.priority < b.priority) return std.math.Order.lt;
        if (a.priority > b.priority) return std.math.Order.gt;
        return std.math.Order.eq;
    }
}.cmp);

fn solve_1(allocator: std.mem.Allocator, input: Input, moves: usize) ![]const u8 {
    const board = &input.board;
    const n = board.rows();
    const m = board.cols();

    var seen: std.ArrayList(bool) = .empty;
    try seen.resize(allocator, n * m);
    @memset(seen.items, false);
    defer seen.deinit(allocator);

    const dragon = board.find_dragon();
    seen.items[board.raw(dragon)] = true;

    var q = Pq.init(allocator, {});
    defer q.deinit();

    try q.add(PqType{ .priority = 0, .p = dragon });
    var answer: usize = 0;
    while (q.items.len > 0) {
        const pq_point = q.remove();
        const last = pq_point.p;
        const last_dist = pq_point.priority;
        if (last_dist == moves) continue;

        for (Moves_I, Moves_J) |di, dj| {
            const p_to = last.add_dij(di, dj) orelse continue;

            if (board.is_valid(p_to)) {
                const raw_p_to = board.raw(p_to);
                if (seen.items[raw_p_to]) continue;

                seen.items[raw_p_to] = true;
                try q.add(PqType{ .priority = last_dist + 1, .p = p_to });

                if (board.is_sheep(p_to)) {
                    answer += 1;
                }
            }
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input, moves: usize) ![]const u8 {
    const board = &input.board;
    const n = board.rows();
    const m = board.cols();

    var seen: std.ArrayList(bool) = .empty;
    try seen.resize(allocator, n * m);
    @memset(seen.items, false);
    defer seen.deinit(allocator);

    var dist: std.ArrayList(usize) = .empty;
    try dist.resize(allocator, n * m);
    @memset(dist.items, 0);
    defer dist.deinit(allocator);

    const dragon = board.find_dragon();
    seen.items[board.raw(dragon)] = true;

    var q = Pq.init(allocator, {});
    defer q.deinit();

    try q.add(PqType{ .priority = 0, .p = dragon });
    while (q.items.len > 0) {
        const pq_point = q.remove();
        const last = pq_point.p;
        const last_dist = pq_point.priority;
        if (last_dist == moves) continue;

        for (Moves_I, Moves_J) |di, dj| {
            const p_to = last.add_dij(di, dj) orelse continue;

            if (board.is_valid(p_to)) {
                const raw_p_to = board.raw(p_to);
                if (seen.items[raw_p_to]) continue;

                seen.items[raw_p_to] = true;
                dist.items[raw_p_to] = last_dist + 1;
                try q.add(PqType{ .priority = last_dist + 1, .p = p_to });
            }
        }
    }

    var answer: usize = 0;
    for (0..n) |i| {
        for (0..m) |j| {
            var p = Point{ .i = i, .j = j };
            if (!board.is_sheep(p)) continue;

            for (i..n, 0..) |cur_i, cur_time| {
                p.i = cur_i;
                const raw_p = board.raw(p);
                const dist_p = dist.items[raw_p];

                if (board.is_hideout(p)) continue;
                if (!seen.items[raw_p]) continue;
                if (cur_time > moves) continue;
                if (dist_p > cur_time + 1) continue;

                if (cur_time + 1 == dist_p or
                    @rem(cur_time - dist_p, 2) == 0 or
                    (@rem(cur_time - dist_p, 2) == 1 and cur_time + 1 <= moves))
                {
                    answer += 1;
                    break;
                }
            }
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn hash(sheeps: *const [8]usize, dragon: *const Point) u64 {
    var h: u64 = 0;
    {
        const ptr: [*]const u8 = @ptrCast(sheeps);
        const byte_len = sheeps.len * @sizeOf(usize);
        const bytes: []const u8 = ptr[0..byte_len];
        h ^= std.hash.Wyhash.hash(0, bytes);
    }
    {
        const ptr: [*]const u8 = @ptrCast(dragon);
        const byte_len = @sizeOf(Point);
        const bytes: []const u8 = ptr[0..byte_len];
        h ^= std.hash.Wyhash.hash(0, bytes);
    }

    return h;
}

fn move_dragon(
    allocator: std.mem.Allocator,
    board: *const Board,
    mem_sheeps: *std.AutoHashMap(u64, usize),
    mem_dragon: *std.AutoHashMap(u64, usize),
    dragon: Point,
    sheeps: [8]usize,
) !usize {
    const h = hash(&sheeps, &dragon);
    if (mem_dragon.get(h)) |v| return v;

    var paths: usize = 0;
    for (Moves_I, Moves_J) |di, dj| {
        const dragon_to = dragon.add_dij(di, dj) orelse continue;
        if (!board.is_valid(dragon_to)) continue;

        var sheeps_copy = sheeps;
        if (!board.is_hideout(dragon_to)) {
            for (sheeps_copy, 0..) |sheep_i, sheep_j| {
                if (sheep_i == std.math.maxInt(usize)) continue;

                if (std.meta.eql(Point{ .i = sheep_i, .j = sheep_j }, dragon_to)) {
                    sheeps_copy[sheep_j] = std.math.maxInt(usize);
                }
            }
        }

        var all_eaten = true;
        for (sheeps_copy) |sheep_i| {
            if (sheep_i != std.math.maxInt(usize)) {
                all_eaten = false;
            }
        }

        paths += if (all_eaten)
            1
        else
            try move_sheep(allocator, board, mem_sheeps, mem_dragon, dragon_to, sheeps_copy);
    }
    try mem_dragon.put(h, paths);

    return paths;
}

fn move_sheep(
    allocator: std.mem.Allocator,
    board: *const Board,
    mem_sheeps: *std.AutoHashMap(u64, usize),
    mem_dragon: *std.AutoHashMap(u64, usize),
    dragon: Point,
    sheeps: [8]usize,
) error{OutOfMemory}!usize {
    const h = hash(&sheeps, &dragon);
    if (mem_sheeps.get(h)) |v| return v;

    var can_sheep_move = false;
    var paths: usize = 0;
    for (sheeps, 0..) |sheep_i, sheep_j| {
        if (sheep_i == std.math.maxInt(usize)) continue;

        const sheep_to = Point{ .i = sheep_i + 1, .j = sheep_j };
        if (sheep_to.i == board.rows()) {
            can_sheep_move = true;
            // the sheep is out
        } else if (std.meta.eql(sheep_to, dragon) and !board.is_hideout(sheep_to)) {
            // nothing
        } else {
            var sheeps_copy = sheeps;
            sheeps_copy[sheep_j] = sheep_to.i;
            can_sheep_move = true;
            paths += try move_dragon(allocator, board, mem_sheeps, mem_dragon, dragon, sheeps_copy);
        }
    }

    const result = if (can_sheep_move) paths else try move_dragon(allocator, board, mem_sheeps, mem_dragon, dragon, sheeps);
    try mem_sheeps.put(h, result);

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const board = &input.board;

    const n = board.rows();
    const m = board.cols();
    std.debug.assert(m < 8);

    var sheeps: [8]usize = undefined;
    for (&sheeps) |*s| {
        s.* = std.math.maxInt(usize);
    }

    for (0..n) |i| {
        for (0..m) |j| {
            if (board.is_sheep(Point{ .i = i, .j = j })) {
                std.debug.assert(sheeps[j] == std.math.maxInt(usize));
                sheeps[j] = i;
            }
        }
    }

    var mem_sheeps = std.AutoHashMap(u64, usize).init(allocator);
    defer mem_sheeps.deinit();

    var mem_dragon = std.AutoHashMap(u64, usize).init(allocator);
    defer mem_dragon.deinit();

    const dragon = board.find_dragon();
    const answer = try move_sheep(allocator, board, &mem_sheeps, &mem_dragon, dragon, sheeps);
    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day10/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "27";
        const answer = try solve_1(allocator, input, 3);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day10/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "156";
        const answer = try solve_1(allocator, input, 4);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}

test "Part 2" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day10/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "27";
        const answer = try solve_2(allocator, input, 3);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day10/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "1720";
        const answer = try solve_2(allocator, input, 20);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}

test "Part 3" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day10/input/input_3_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "15";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day10/input/input_3_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "8";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day10/input/input_3_sample_3.txt");
        defer input.deinit(allocator);

        const expected = "44";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day10/input/input_3_sample_4.txt");
        defer input.deinit(allocator);

        const expected = "4406";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day10/input/input_3_sample_5.txt");
        defer input.deinit(allocator);

        const expected = "13033988838";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day10/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "1389524228800";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
