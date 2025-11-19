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

const Moves_I = [_]i32{ 0, -1, 0, 1 };
const Moves_J = [_]i32{ -1, 0, 1, 0 };

const Cell = union(enum) {
    Alive: usize,
    Burnt: usize,
};

const Grid = struct {
    grid: std.ArrayList(std.ArrayList(Cell)),

    pub fn init(grid: std.ArrayList(std.ArrayList(Cell))) Grid {
        return Grid{ .grid = grid };
    }

    pub fn rows(self: *const Grid) usize {
        return self.grid.items.len;
    }

    pub fn cols(self: *const Grid) usize {
        std.debug.assert(self.grid.items.len > 0);

        return self.grid.items[0].items.len;
    }

    pub fn is_valid(self: *const Grid, p: *const Point) bool {
        return p.i >= 0 and p.i < self.rows() and p.j >= 0 and p.j < self.cols();
    }

    pub fn bfs_count(
        self: *Grid,
        allocator: std.mem.Allocator,
        barrels: std.ArrayList(Point),
        burning: bool,
    ) !usize {
        const n = self.rows();
        const m = self.cols();

        var barrels_mut = barrels;
        defer barrels_mut.deinit(allocator);

        var seen: std.ArrayList(bool) = .empty;
        try seen.resize(allocator, n * m);
        defer seen.deinit(allocator);
        @memset(seen.items, false);

        var q: std.Deque(Point) = .empty;
        defer q.deinit(allocator);

        for (barrels_mut.items) |barrel| {
            try q.pushBack(allocator, barrel);

            seen.items[self.index(&barrel)] = true;
            self.maybe_burn(&barrel, burning);
        }

        var cnt: usize = barrels_mut.items.len;
        while (q.len > 0) {
            const cur = q.popFront().?;
            const size_cur = self.size(&cur);

            for (Moves_I, Moves_J) |di, dj| {
                const p_to = cur.add_dij(di, dj) orelse continue;
                if (!self.is_valid(&p_to)) continue;

                const index_p_to = self.index(&p_to);
                const size_p_to = self.size(&p_to);

                if (!self.is_burnt(&p_to) and !seen.items[index_p_to] and size_cur >= size_p_to) {
                    cnt += 1;
                    seen.items[index_p_to] = true;
                    self.maybe_burn(&p_to, burning);

                    try q.pushBack(allocator, p_to);
                }
            }
        }

        return cnt;
    }

    fn is_burnt(self: *const Grid, point: *const Point) bool {
        std.debug.assert(self.is_valid(point));

        const item = &self.grid.items[point.i].items[point.j];
        return switch (item.*) {
            .Alive => |_| false,
            .Burnt => |_| true,
        };
    }

    fn maybe_burn(self: *Grid, point: *const Point, burning: bool) void {
        if (!burning) return;

        const item = &self.grid.items[point.i].items[point.j];
        switch (item.*) {
            .Alive => |v| item.* = Cell{ .Burnt = v },
            .Burnt => |_| unreachable,
        }
    }

    fn size(self: *const Grid, point: *const Point) usize {
        std.debug.assert(self.is_valid(point));

        const item = &self.grid.items[point.i].items[point.j];
        return switch (item.*) {
            .Alive => |v| v,
            .Burnt => |v| v,
        };
    }

    fn index(self: *const Grid, point: *const Point) usize {
        std.debug.assert(self.is_valid(point));

        const m = self.cols();

        return point.i * m + point.j;
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

        var grid: std.ArrayList(std.ArrayList(Cell)) = .empty;
        errdefer grid.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |row_str| {
            var row: std.ArrayList(Cell) = .empty;
            errdefer row.deinit(allocator);

            for (row_str) |c| {
                try row.append(allocator, Cell{ .Alive = @as(usize, @intCast(c - '0')) });
            }

            try grid.append(allocator, row);
        }

        return Input{
            .file_content = file_content,
            .grid = Grid{ .grid = grid },
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
        1 => solve_1(allocator, input),
        2 => solve_2(allocator, input),
        3 => solve_3(allocator, input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    var input_mut = input;

    var barrels: std.ArrayList(Point) = .empty;
    try barrels.append(allocator, Point{ .i = 0, .j = 0 });

    const answer = try input_mut.grid.bfs_count(allocator, barrels, false);
    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    var input_mut = input;

    const n = input_mut.grid.rows();
    const m = input_mut.grid.cols();

    var barrels: std.ArrayList(Point) = .empty;
    try barrels.append(allocator, Point{ .i = 0, .j = 0 });
    try barrels.append(allocator, Point{ .i = n - 1, .j = m - 1 });

    const answer = try input_mut.grid.bfs_count(allocator, barrels, false);
    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    var input_mut = input;

    const n = input_mut.grid.rows();
    const m = input_mut.grid.cols();

    var sum: usize = 0;
    for (0..3) |_| {
        var ma_size: usize = 0;
        var ma_point = Point{ .i = 0, .j = 0 };

        for (0..n) |i| {
            for (0..m) |j| {
                const cur_point = Point{ .i = i, .j = j };
                if (input_mut.grid.is_burnt(&cur_point)) continue;

                var barrels: std.ArrayList(Point) = .empty;
                try barrels.append(allocator, cur_point);

                const size = try input_mut.grid.bfs_count(allocator, barrels, false);
                if (size > ma_size) {
                    ma_size = size;
                    ma_point = cur_point;
                }
            }
        }

        var barrels: std.ArrayList(Point) = .empty;
        try barrels.append(allocator, ma_point);

        sum += try input_mut.grid.bfs_count(allocator, barrels, true);
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{sum});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day12/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "16";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day12/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "225";
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
        var input = try Input.parse(allocator, "day12/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "58";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day12/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "5721";
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
        var input = try Input.parse(allocator, "day12/input/input_3_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "14";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day12/input/input_3_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "136";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day12/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "3989";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
