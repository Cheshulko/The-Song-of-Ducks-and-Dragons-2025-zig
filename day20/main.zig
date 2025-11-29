const std = @import("std");

const R: usize = 3;

const Point = struct {
    i: usize,
    j: usize,
    r: usize,

    pub fn add_dij(self: *const Point, di: i32, dj: i32, with_rotation: bool) ?Point {
        const i_: i32 = @intCast(self.i);
        const j_: i32 = @intCast(self.j);

        if (i_ + di >= 0 and j_ + dj >= 0) {
            return Point{
                .i = @intCast(i_ + di),
                .j = @intCast(j_ + dj),
                .r = (self.r + @as(usize, if (with_rotation) 1 else 0)) % R,
            };
        }

        return null;
    }
};

const Input = struct {
    file_content: []u8,
    r: usize,
    triangles: std.ArrayList([]u8),

    pub fn parse(allocator: std.mem.Allocator, file_path: []const u8) !Input {
        return Input.init(allocator, file_path);
    }

    pub fn rows(self: *const Input) usize {
        return self.triangles.items.len;
    }

    pub fn cols(self: *const Input) usize {
        return self.triangles.items[0].len;
    }

    pub fn is_valid(self: *const Input, p: Point) bool {
        return p.i >= 0 and p.i < self.rows() and p.j >= 0 and p.j < self.cols();
    }

    pub fn get(self: *const Input, p: Point) u8 {
        std.debug.assert(self.is_valid(p));

        return self.triangles.items[p.i][p.j];
    }

    pub fn find_first(self: *const Input, c: usize) ?Point {
        const n = self.rows();
        const m = self.cols();
        const items = self.triangles.items;

        for (0..n) |i| {
            for (0..m) |j| {
                if (items[i][j] == c) return Point{
                    .i = i,
                    .j = j,
                    .r = self.r,
                };
            }
        }

        return null;
    }

    pub fn can_move(self: *const Input, from: Point, to: Point) bool {
        var from_mut = from;
        var to_mut = to;
        if (from_mut.i < to_mut.i) {
            std.mem.swap(Point, &from_mut, &to_mut);
        }

        const to_sym = self.get(to);
        const valid_to = to_sym == 'S' or to_sym == 'E' or to_sym == 'T';

        std.debug.assert(from_mut.i - to_mut.i == 1 or to_mut.i == from_mut.i);
        if (from_mut.i - to_mut.i == 1) {
            return valid_to and from_mut.i & 1 == from_mut.j & 1;
        } else {
            return valid_to;
        }
    }

    pub fn index(self: *const Input, point: Point) usize {
        std.debug.assert(self.is_valid(point));

        const n = self.rows();
        const m = self.cols();

        return point.i * m + point.j + (n * m) * point.r;
    }

    pub fn rotateClockwise(self: *Input) void {
        const n = self.rows();
        const grid = self.triangles.items;
        const k = 2 * n - 2;

        var r: usize = 0;
        while (r < n) : (r += 1) {
            var c: usize = r;
            const limit = k - r;

            while (c <= limit) : (c += 1) {
                const r2 = (c - r) >> 1;
                const c2 = k - r - c + r2;
                const r3 = (c2 - r2) >> 1;
                const c3 = k - r2 - c2 + r3;
                const p1_vs_p2 = if (r != r2) r < r2 else c < c2;
                const p1_vs_p3 = if (r != r3) r < r3 else c < c3;

                if (p1_vs_p2 and p1_vs_p3) {
                    const tmp = grid[r3][c3];
                    grid[r3][c3] = grid[r2][c2];
                    grid[r2][c2] = grid[r][c];
                    grid[r][c] = tmp;
                }
            }
        }

        self.r = (self.r + 1) % R;
    }

    fn init(allocator: std.mem.Allocator, file_path: []const u8) !Input {
        const file_content = try std.fs.cwd().readFileAlloc(
            file_path,
            allocator,
            .unlimited,
        );
        errdefer allocator.free(file_content);

        var triangles: std.ArrayList([]u8) = .empty;
        errdefer triangles.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |row| {
            const dst = try allocator.alloc(u8, row.len);
            std.mem.copyForwards(u8, dst, row);
            try triangles.append(allocator, dst);
        }

        return Input{
            .file_content = file_content,
            .r = 0,
            .triangles = triangles,
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);

        for (0..self.triangles.items.len) |i| {
            allocator.free(self.triangles.items[i]);
        }
        self.triangles.deinit(allocator);
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
        1 => solve_1(allocator, input),
        2 => solve_2(allocator, input),
        3 => solve_3(allocator, input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const n = input.rows();
    const m = input.cols();
    const items = input.triangles.items;

    var answer: usize = 0;
    for (0..n) |i| {
        for (0..m) |j| {
            if (items[i][j] != 'T') continue;
            if (j + 1 < m and items[i][j] == items[i][j + 1]) answer += 1;
            if (i > 0 and i & 1 == j & 1 and items[i][j] == items[i - 1][j]) answer += 1;
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

const Moves_I = [_]i32{ 0, -1, 0, 1, 0 };
const Moves_J = [_]i32{ -1, 0, 1, 0, 0 };

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const n = input.rows();
    const m = input.cols();

    const start = input.find_first('S').?;
    const end = input.find_first('E').?;

    var dist: std.ArrayList(i32) = .empty;
    defer dist.deinit(allocator);
    try dist.resize(allocator, n * m);
    @memset(dist.items, -1);

    var q: std.Deque(Point) = .empty;
    defer q.deinit(allocator);

    dist.items[input.index(start)] = 0;
    try q.pushBack(allocator, start);

    while (q.popFront()) |cur| {
        const cur_index = input.index(cur);

        for (Moves_I, Moves_J) |di, dj| {
            const to = cur.add_dij(di, dj, false) orelse continue;
            if (!input.is_valid(to)) continue;

            const to_index = input.index(to);
            if (dist.items[to_index] != -1) continue;
            if (!input.can_move(cur, to)) continue;

            const to_dist = dist.items[cur_index] + 1;
            dist.items[to_index] = to_dist;
            try q.pushBack(allocator, to);
        }
    }

    const answer = dist.items[input.index(end)];
    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input_const: Input) ![]const u8 {
    var input = input_const;
    const n = input.rows();
    const m = input.cols();

    const start = input.find_first('S').?;

    var dist: std.ArrayList(i32) = .empty;
    defer dist.deinit(allocator);
    try dist.resize(allocator, n * m * 3);
    @memset(dist.items, -1);

    var q: std.Deque(Point) = .empty;
    defer q.deinit(allocator);

    dist.items[input.index(start)] = 0;
    try q.pushBack(allocator, start);

    while (q.popFront()) |cur| {
        const r_cur = cur.r;
        while (input.r != r_cur) {
            input.rotateClockwise();
        }

        input.rotateClockwise();
        const cur_index = input.index(cur);

        for (Moves_I, Moves_J) |di, dj| {
            const to = cur.add_dij(di, dj, true) orelse continue;
            if (!input.is_valid(to)) continue;

            const to_index = input.index(to);
            if (dist.items[to_index] != -1) continue;
            if (!input.can_move(cur, to)) continue;

            const to_dist = dist.items[cur_index] + 1;
            dist.items[to_index] = to_dist;
            try q.pushBack(allocator, to);
        }
    }

    var answer: i32 = std.math.maxInt(i32);
    for (0..R) |_| {
        const end = input.find_first('E').?;
        const d = dist.items[input.index(end)];
        if (d != -1) answer = @min(answer, d);

        input.rotateClockwise();
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day20/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "7";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }

    {
        var input = try Input.parse(allocator, "day20/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "124";
        const answer = try solve_1(allocator, input);
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
        var input = try Input.parse(allocator, "day20/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "32";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day20/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "587";
        const answer = try solve_2(allocator, input);
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
        var input = try Input.parse(allocator, "day20/input/input_3_sample.txt");
        defer input.deinit(allocator);

        const expected = "23";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day20/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "479";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
