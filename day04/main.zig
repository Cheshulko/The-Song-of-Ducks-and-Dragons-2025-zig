const std = @import("std");

const Input = struct {
    numbers: std.ArrayList(i512),
    number_pairs: std.ArrayList(i512),
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

        var numbers: std.ArrayList(i512) = .empty;
        errdefer numbers.deinit(allocator);

        var number_pairs: std.ArrayList(i512) = .empty;
        errdefer number_pairs.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |line| {
            var it_n = std.mem.splitScalar(u8, line, '|');

            try numbers.append(allocator, try std.fmt.parseInt(i512, it_n.next().?, 10));
            if (it_n.next()) |pair| {
                try number_pairs.append(allocator, try std.fmt.parseInt(i512, pair, 10));
            }
        }

        return Input{
            .numbers = numbers,
            .number_pairs = number_pairs,
            .file_content = file_content,
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        self.numbers.deinit(allocator);
        self.number_pairs.deinit(allocator);
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
        2 => solve_2(allocator, input),
        3 => solve_3(allocator, input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const rot = 2025;
    const n = input.numbers.items.len;

    const first = input.numbers.items[0];
    const last = input.numbers.items[n - 1];
    const ans = @divTrunc(first * rot, last);
    const result = try std.fmt.allocPrint(allocator, "{}", .{ans});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const rot = 10000000000000;
    const n = input.numbers.items.len;

    const first = input.numbers.items[0];
    const last = input.numbers.items[n - 1];
    const ans = @divFloor(last * rot + first - 1, first);
    const result = try std.fmt.allocPrint(allocator, "{}", .{ans});

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const n = input.number_pairs.items.len;
    const rot = 100;

    var mul: i512 = 1;
    var cur: i512 = 1;
    for (0..n) |i| {
        const lcm = @divExact(
            cur * input.numbers.items[i + 1],
            gcd(i512, cur, input.numbers.items[i + 1]),
        );
        const turns = @divExact(lcm, input.numbers.items[i + 1]);

        input.numbers.items[i + 1] = lcm;
        input.number_pairs.items[i] = turns * input.number_pairs.items[i];
        mul *= @divExact(lcm, cur);
        cur = input.number_pairs.items[i];
    }

    const x = @divFloor(cur * input.numbers.items[0] * rot, mul);
    const y = @divFloor(x, input.numbers.items[n + 1]);
    const result = try std.fmt.allocPrint(allocator, "{}", .{y});

    return result;
}

fn gcd(comptime T: type, a_in: T, b_in: T) T {
    var a = a_in;
    var b = b_in;

    while (b != 0) {
        const temp = b;
        b = @mod(a, b);
        a = temp;
    }
    return a;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day04/input/input_1_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "32400";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day04/input/input_1_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "15888";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day04/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "12735";
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
        var input = try Input.parse(allocator, "day04/input/input_2_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "625000000000";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day04/input/input_2_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "1274509803922";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day04/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "2694805194806";
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
        var input = try Input.parse(allocator, "day04/input/input_3_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "400";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day04/input/input_3_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "6818";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day04/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "341891077610";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
