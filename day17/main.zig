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

const Grid = struct {
    grid: std.ArrayList(std.ArrayList(i32)),
    volcan_pos: Point,
    start_pos: ?Point,

    pub fn init(grid: std.ArrayList(std.ArrayList(i32))) Grid {
        var volcan_pos = Point{ .i = 0, .j = 0 };
        var start_pos: ?Point = null;

        const n = grid.items.len;
        const m = grid.items[0].items.len;
        for (0..n) |i| {
            for (0..m) |j| {
                if (grid.items[i].items[j] == -1) {
                    volcan_pos.i = i;
                    volcan_pos.j = j;
                }
                if (grid.items[i].items[j] == -2) {
                    start_pos = Point{ .i = i, .j = j };
                }
            }
        }

        return Grid{
            .grid = grid,
            .volcan_pos = volcan_pos,
            .start_pos = start_pos,
        };
    }

    pub fn rows(self: *const Grid) usize {
        return self.grid.items.len;
    }

    pub fn cols(self: *const Grid) usize {
        std.debug.assert(self.grid.items.len > 0);

        return self.grid.items[0].items.len;
    }

    pub fn get(self: *const Grid, p: Point) i32 {
        std.debug.assert(self.is_valid(p));

        return self.grid.items[p.i].items[p.j];
    }

    pub fn is_valid(self: *const Grid, p: Point) bool {
        return p.i >= 0 and p.i < self.rows() and p.j >= 0 and p.j < self.cols();
    }

    pub fn check_within_radius(self: *const Grid, p: Point, radius: usize) bool {
        const vi = self.volcan_pos.i;
        const vj = self.volcan_pos.j;

        const di = @max(p.i, vi) - @min(p.i, vi);
        const dj = @max(p.j, vj) - @min(p.j, vj);

        return di * di + dj * dj <= radius * radius;
    }

    fn index(self: *const Grid, point: Point) usize {
        std.debug.assert(self.is_valid(point));

        const m = self.cols();

        return point.i * m + point.j;
    }

    pub fn solve(self: *const Grid, allocator: std.mem.Allocator, radius: usize) !i32 {
        var left = try self.bfs_side(allocator, radius, true);
        defer left.deinit(allocator);

        var right = try self.bfs_side(allocator, radius, false);
        defer right.deinit(allocator);

        const start = self.start_pos.?;
        const n = self.rows();

        var best: i32 = std.math.maxInt(i32);
        for (self.volcan_pos.i + radius + 1..n) |i| {
            const p = Point{ .i = i, .j = start.j };
            const v = self.grid.items[p.i].items[p.j];

            const l = left.items[self.index(p)];
            const r = right.items[self.index(p)];
            if (r == -1 or l == -1) continue;

            best = @min(best, l + r - v);
        }

        return best;
    }

    fn bfs_side(self: *const Grid, allocator: std.mem.Allocator, radius: usize, left: bool) !std.ArrayList(i32) {
        const Moves_I = [_]i32{ 0, -1, 0, 1 };
        const Moves_J = [_]i32{ -1, 0, 1, 0 };

        const n = self.rows();
        const m = self.cols();

        const start = self.start_pos.?;

        var dist: std.ArrayList(i32) = .empty;
        try dist.resize(allocator, n * m);
        @memset(dist.items, -1);

        var qs: [10]std.Deque(Point) = undefined;
        for (&qs) |*q| q.* = .empty;
        defer {
            for (0..10) |i| {
                qs[i].deinit(allocator);
            }
        }

        dist.items[self.index(start)] = 0;
        try qs[0].pushBack(allocator, start);

        var size: usize = 1;
        var ind: usize = 0;
        while (size > 0) {
            if (qs[ind].len == 0) {
                ind = (ind + 1) % 10;
                continue;
            }

            size -= 1;
            const cur_p = qs[ind].popFront().?;

            for (Moves_I, Moves_J) |di, dj| {
                const p_to = cur_p.add_dij(di, dj) orelse continue;
                if (left and p_to.j > start.j + radius) continue;
                if (!left and p_to.j < start.j - radius) continue;
                if (!self.is_valid(p_to)) continue;
                if (self.check_within_radius(p_to, radius)) continue;

                const index_p_to = self.index(p_to);
                if (dist.items[index_p_to] == -1) {
                    const d = self.grid.items[p_to.i].items[p_to.j];
                    const cur_d = dist.items[self.index(cur_p)];

                    dist.items[index_p_to] = cur_d + d;
                    size += 1;
                    try qs[(ind + @as(usize, @intCast(d))) % 10].pushBack(allocator, p_to);
                }
            }
        }

        return dist;
    }

    pub fn deinit(self: *Grid, allocator: std.mem.Allocator) void {
        while (self.grid.items.len > 0) {
            var inner = self.grid.pop().?;
            inner.deinit(allocator);
        }
        self.grid.deinit(allocator);
    }
};

const Input = struct {
    file_content: []const u8,
    grid: Grid,

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

        var grid: std.ArrayList(std.ArrayList(i32)) = .empty;
        errdefer grid.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |row_str| {
            var row: std.ArrayList(i32) = .empty;
            errdefer row.deinit(allocator);

            for (row_str) |c| {
                if (c == '@') {
                    try row.append(allocator, -1);
                } else if (c == 'S') {
                    try row.append(allocator, -2);
                } else {
                    try row.append(allocator, @as(i32, c - '0'));
                }
            }

            try grid.append(allocator, row);
        }

        return Input{
            .file_content = file_content,
            .grid = Grid.init(grid),
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.grid.deinit(allocator);
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
        1 => solve_1(allocator, input, 10),
        2 => solve_2(allocator, input),
        3 => solve_3(allocator, input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(allocator: std.mem.Allocator, input: Input, radius: usize) ![]const u8 {
    const volcan_pos = input.grid.volcan_pos;
    const vi = volcan_pos.i;
    const vj = volcan_pos.j;

    const n = input.grid.rows();
    const m = input.grid.cols();

    var answer: i32 = 0;
    for (0..n) |i| {
        for (0..m) |j| {
            if (i == vi and j == vj) continue;

            const p = Point{ .i = i, .j = j };
            if (input.grid.check_within_radius(p, radius)) {
                answer += input.grid.get(p);
            }
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const volcan_pos = input.grid.volcan_pos;
    const vi = volcan_pos.i;
    const vj = volcan_pos.j;

    const n = input.grid.rows();
    const m = input.grid.cols();
    const mi_r = @min(vi, vj, n - 1 - vi, m - 1 - vj);

    var radiuses: std.ArrayList(i32) = .empty;
    try radiuses.resize(allocator, 2 * @max(n, m));
    @memset(radiuses.items, 0);
    defer radiuses.deinit(allocator);

    for (0..n) |i| {
        for (0..m) |j| {
            if (i == vi and j == vj) continue;
            const di = @max(i, vi) - @min(i, vi);
            const dj = @max(j, vj) - @min(j, vj);
            const d = di * di + dj * dj;
            const df: f32 = @floatFromInt(d);

            var r: usize = @intFromFloat(std.math.sqrt(df));
            if (r * r < d) r += 1;
            if (r > mi_r) continue;

            radiuses.items[r] += @intCast(input.grid.get(Point{ .i = i, .j = j }));
        }
    }

    var answer: i32 = 0;
    var ma: i32 = 0;
    for (radiuses.items, 0..) |it, r| {
        if (it >= ma) {
            ma = it;
            answer = @max(answer, it * @as(i32, @intCast(r)));
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const ma_r = @min(input.grid.cols(), input.grid.rows());
    for (1..ma_r) |r| {
        const t = try input.grid.solve(allocator, r);

        if (t < 30 * (1 + r)) {
            const answer = t * @as(i32, @intCast(r));
            const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

            return result;
        }
    }

    unreachable;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day17/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "1573";
        const answer = try solve_1(allocator, input, 10);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }

    {
        var input = try Input.parse(allocator, "day17/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "1611";
        const answer = try solve_1(allocator, input, 10);
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
        var input = try Input.parse(allocator, "day17/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "1090";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day17/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "66027";
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
        var input = try Input.parse(allocator, "day17/input/input_3_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "592";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day17/input/input_3_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "330";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day17/input/input_3_sample_3.txt");
        defer input.deinit(allocator);

        const expected = "3180";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day17/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "44004";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
