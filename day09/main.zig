const std = @import("std");

const Scale = struct {
    index: usize,
    scale: []const u8,

    fn is_child(self: *const Scale, p1: *const Scale, p2: *const Scale) bool {
        const n = self.scale.len;
        std.debug.assert(n == p1.scale.len);
        std.debug.assert(n == p2.scale.len);

        for (0..n) |i| {
            if (self.scale[i] != p1.scale[i] and self.scale[i] != p2.scale[i]) {
                return false;
            }
        }

        return true;
    }

    fn similarity_to(self: *const Scale, p: *const Scale) usize {
        const n = self.scale.len;
        std.debug.assert(n == p.scale.len);

        var similarity: usize = 0;
        for (0..n) |i| {
            if (self.scale[i] == p.scale[i]) {
                similarity += 1;
            }
        }

        return similarity;
    }
};

const Input = struct {
    file_content: []u8,
    scales: std.ArrayList(Scale),

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

        var scales: std.ArrayList(Scale) = .empty;
        errdefer scales.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |scale_str| {
            var scale_it = std.mem.splitScalar(u8, scale_str, ':');
            const index = try std.fmt.parseInt(usize, scale_it.next().?, 10);
            const scale = scale_it.next().?;

            try scales.append(allocator, Scale{
                .index = index,
                .scale = scale,
            });
        }

        return Input{
            .file_content = file_content,
            .scales = scales,
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.scales.deinit(allocator);
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
    const n = input.scales.items.len;
    std.debug.assert(n == 3);

    const scales = input.scales.items;

    for (0..n) |i| {
        for (0..n) |j| {
            if (i == j) continue;
            const k = n - i - j;

            if (scales[i].is_child(&scales[j], &scales[k])) {
                const answer = scales[i].similarity_to(&scales[j]) * scales[i].similarity_to(&scales[k]);
                const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

                return result;
            }
        }
    }

    unreachable;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const n = input.scales.items.len;

    const scales = input.scales.items;

    var answer: usize = 0;
    for (0..n) |i| {
        for (0..n) |j| {
            for ((j + 1)..n) |k| {
                if (i == j) continue;
                if (i == k) continue;

                if (scales[i].is_child(&scales[j], &scales[k])) {
                    answer += scales[i].similarity_to(&scales[j]) * scales[i].similarity_to(&scales[k]);
                }
            }
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

const Graph = std.ArrayList(std.ArrayList(usize));

fn dfs(cur: usize, connections: *const Graph, seen: *std.ArrayList(bool), members: *usize) usize {
    seen.items[cur] = true;
    members.* += 1;

    var sum: usize = cur + 1;
    for (connections.items[cur].items) |to| {
        if (!seen.items[to]) {
            sum += dfs(to, connections, seen, members);
        }
    }

    return sum;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const n = input.scales.items.len;

    var connections: Graph = .empty;
    for (0..n) |_| {
        try connections.append(allocator, .empty);
    }
    defer {
        while (connections.items.len > 0) {
            var inner = connections.pop().?;
            inner.deinit(allocator);
        }
        connections.deinit(allocator);
    }

    const scales = input.scales.items;
    for (0..n) |i| {
        for (0..n) |j| {
            for ((j + 1)..n) |k| {
                if (i == j) continue;
                if (i == k) continue;

                if (scales[i].is_child(&scales[j], &scales[k])) {
                    try connections.items[i].append(allocator, j);
                    try connections.items[j].append(allocator, i);

                    try connections.items[j].append(allocator, k);
                    try connections.items[k].append(allocator, j);

                    try connections.items[i].append(allocator, k);
                    try connections.items[k].append(allocator, i);
                }
            }
        }
    }

    var seen: std.ArrayList(bool) = .empty;
    try seen.resize(allocator, n);
    @memset(seen.items, false);
    defer seen.deinit(allocator);

    var answer_members: usize = 0;
    var answer: usize = 0;
    for (0..n) |i| {
        if (!seen.items[i]) {
            var members: usize = 0;
            const sum = dfs(i, &connections, &seen, &members);

            if (members >= answer_members) {
                answer = @max(answer, sum);
                answer_members = members;
            }
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day09/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "414";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day09/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "5920";
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
        var input = try Input.parse(allocator, "day09/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "1245";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day09/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "315367";
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
        var input = try Input.parse(allocator, "day09/input/input_3_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "12";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day09/input/input_3_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "36";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day09/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "40394";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
