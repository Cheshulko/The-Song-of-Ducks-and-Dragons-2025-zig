const std = @import("std");

const Triple = [3]i32;

const Input = struct {
    file_content: []const u8,
    triples: std.ArrayList(Triple),

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

        var triples: std.ArrayList(Triple) = .empty;
        errdefer triples.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |t| {
            var it_t = std.mem.splitScalar(u8, t, ',');
            var triple = [3]i32{ 0, 0, 0 };
            for (0..3) |i| {
                triple[i] = try std.fmt.parseInt(i32, it_t.next().?, 10);
            }

            try triples.append(allocator, triple);
        }

        return Input{
            .file_content = file_content,
            .triples = triples,
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.triples.deinit(allocator);
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
        2 => solve_1(allocator, input),
        3 => solve_1(allocator, input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn abs(x: i32) i32 {
    return if (x < 0) -x else x;
}

fn solve(allocator: std.mem.Allocator, input: Input) !i32 {
    var ys = std.AutoHashMap(i32, void).init(allocator);
    defer ys.deinit();
    try ys.put(0, {});

    var ys_to = std.AutoHashMap(i32, void).init(allocator);
    defer ys_to.deinit();

    const n = input.triples.items.len;

    var x_from: i32 = 0;
    var i: usize = 0;
    while (i < n) {
        const x_to = input.triples.items[i][0];

        ys_to.clearRetainingCapacity();
        while (i < n and input.triples.items[i][0] == x_to) : (i += 1) {
            var triple = input.triples.items[i];
            var y_cur = triple[1];
            const y_end = y_cur + triple[2];

            while (y_cur < y_end) : (y_cur += 1) {
                if ((x_to + y_cur) & 1 == 1) continue;

                var it = ys.keyIterator();
                while (it.next()) |y_from| {
                    if (abs(y_cur - y_from.*) <= x_to - x_from) {
                        try ys_to.put(y_cur, {});
                    }
                }
            }
        }

        x_from = x_to;
        std.mem.swap(std.AutoHashMap(i32, void), &ys, &ys_to);
    }

    var mi_y: i32 = std.math.maxInt(i32);
    var it = ys.keyIterator();
    while (it.next()) |y_from| {
        mi_y = @min(mi_y, y_from.*);
    }

    return mi_y + @divFloor(x_from - mi_y, 2);
}

fn solve_1(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const answer = try solve(allocator, input);
    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day19/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "24";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }

    {
        var input = try Input.parse(allocator, "day19/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "49";
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
        var input = try Input.parse(allocator, "day19/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "22";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day19/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "743";
        const answer = try solve_1(allocator, input);
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
        var input = try Input.parse(allocator, "day19/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "4380582";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
