const std = @import("std");

const Number = struct {
    x: i64,
    y: i64,

    // [X1,Y1] + [X2,Y2] = [X1 + X2, Y1 + Y2]
    pub fn add(self: *const Number, other: Number) Number {
        return Number{ .x = self.x + other.x, .y = self.y + other.y };
    }

    // [X1,Y1] * [X2,Y2] = [X1 * X2 - Y1 * Y2, X1 * Y2 + Y1 * X2]
    pub fn mul(self: *const Number, other: Number) Number {
        return Number{ .x = self.x * other.x - self.y * other.y, .y = self.x * other.y + self.y * other.x };
    }

    // [X1,Y1] / [X2,Y2] = [X1 / X2, Y1 / Y2]
    pub fn div(self: *const Number, other: Number) Number {
        return Number{ .x = @divTrunc(self.x, other.x), .y = @divTrunc(self.y, other.y) };
    }
};

const Input = struct {
    number: Number,
    file_content: []u8,

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

        const start = std.mem.indexOfScalar(u8, file_content, '[') orelse return error.InvalidFormat;
        const end = std.mem.indexOfScalar(u8, file_content, ']') orelse return error.InvalidFormat;

        const inside = file_content[start + 1 .. end];

        var it = std.mem.splitScalar(u8, inside, ',');

        const x_str = it.next() orelse return error.InvalidFormat;
        const y_str = it.next() orelse return error.InvalidFormat;

        const x = try std.fmt.parseInt(i64, std.mem.trim(u8, x_str, " "), 10);
        const y = try std.fmt.parseInt(i64, std.mem.trim(u8, y_str, " "), 10);

        return Input{ .number = Number{ .x = x, .y = y }, .file_content = file_content };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
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
        2 => solve_2(allocator, input, 10),
        3 => solve_2(allocator, input, 1),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const cycles = 3;
    const div = Number{ .x = 10, .y = 10 };

    var cur = Number{ .x = 0, .y = 0 };
    for (0..cycles) |_| {
        cur = cur.mul(cur);
        cur = cur.div(div);
        cur = cur.add(input.number);
    }

    const result = try std.fmt.allocPrint(allocator, "[{},{}]", .{ cur.x, cur.y });

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input, step: i64) ![]const u8 {
    const cycles = 100;
    const div = Number{ .x = 100000, .y = 100000 };
    const delta = Number{ .x = 1000, .y = 1000 };
    const bound: i64 = 1000000;
    const start = input.number;
    const end = start.add(delta);

    var ans: usize = 0;
    var cur = start;
    while (cur.x <= end.x) : (cur.x += step) {
        cur.y = start.y;
        while (cur.y <= end.y) : (cur.y += step) {
            var ok = true;
            var p = Number{ .x = 0, .y = 0 };

            for (0..cycles) |_| {
                p = p.mul(p);
                p = p.div(div);
                p = p.add(cur);

                if (p.x > bound or p.x < -bound or p.y > bound or p.y < -bound) {
                    ok = false;
                    break;
                }
            }

            if (ok) {
                ans += 1;
            }
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{ans});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day02/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "[357,862]";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day02/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "[152392,594587]";
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
        var input = try Input.parse(allocator, "day02/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "4076";
        const answer = try solve_2(allocator, input, 10);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day02/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "1138";
        const answer = try solve_2(allocator, input, 10);
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
        var input = try Input.parse(allocator, "day02/input/input_3_sample.txt");
        defer input.deinit(allocator);

        const expected = "406954";
        const answer = try solve_2(allocator, input, 1);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day02/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "111136";
        const answer = try solve_2(allocator, input, 1);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
