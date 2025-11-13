const std = @import("std");

const Input = struct {
    file_content: []u8,
    numbers: std.ArrayList(usize),

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

        var numbers: std.ArrayList(usize) = .empty;
        errdefer numbers.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, ',');
        while (it.next()) |number| {
            try numbers.append(allocator, try std.fmt.parseInt(usize, number, 10));
        }

        return Input{
            .file_content = file_content,
            .numbers = numbers,
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.numbers.deinit(allocator);
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
        1 => solve_1(allocator, input, 32),
        2 => solve_2(allocator, input, 256),
        3 => solve_3(allocator, input, 256),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(allocator: std.mem.Allocator, input: Input, nails: usize) ![]const u8 {
    const n = input.numbers.items.len;
    const numbers = input.numbers.items;
    const half = @divExact(nails, 2);

    var ans: usize = 0;
    for (1..n) |i| {
        const diff = @max(numbers[i], numbers[i - 1]) - @min(numbers[i], numbers[i - 1]);
        if (diff == half) {
            ans += 1;
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{ans});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input, nails: usize) ![]const u8 {
    const n = input.numbers.items.len;
    const numbers = input.numbers.items;

    var cnt: std.ArrayList(std.ArrayList(usize)) = .empty;
    defer cnt.deinit(allocator);

    for (0..nails) |_| {
        try cnt.append(allocator, .empty);
    }

    var ans: usize = 0;
    for (1..n) |i| {
        const mi = @min(numbers[i], numbers[i - 1]) - 1;
        const ma = @max(numbers[i], numbers[i - 1]) - 1;

        for ((mi + 1)..ma) |start| {
            for (cnt.items[start].items) |end| {
                if (end < mi or end > ma) {
                    ans += 1;
                }
            }
        }

        try cnt.items[mi].append(allocator, ma);
        try cnt.items[ma].append(allocator, mi);
    }

    while (cnt.items.len > 0) {
        var inner = cnt.pop().?;
        inner.deinit(allocator);
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{ans});

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input, nails: usize) ![]const u8 {
    const n = input.numbers.items.len;
    const numbers = input.numbers.items;

    var cnt: std.ArrayList(std.ArrayList(usize)) = .empty;
    defer cnt.deinit(allocator);

    for (0..nails) |_| {
        try cnt.append(allocator, .empty);
    }

    for (1..n) |i| {
        const mi = @min(numbers[i], numbers[i - 1]) - 1;
        const ma = @max(numbers[i], numbers[i - 1]) - 1;

        try cnt.items[mi].append(allocator, ma);
        try cnt.items[ma].append(allocator, mi);
    }

    var ans: usize = 0;
    for (0..nails) |i| {
        for ((i + 1)..nails) |j| {
            var cur: usize = 0;
            for (i..j) |start| {
                for (cnt.items[start].items) |end| {
                    if (start == i) {
                        if (end == j) {
                            cur += 1;
                        }
                    } else {
                        if (end < i or end > j) {
                            cur += 1;
                        }
                    }
                }
            }
            ans = @max(ans, cur);
        }
    }

    while (cnt.items.len > 0) {
        var inner = cnt.pop().?;
        inner.deinit(allocator);
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{ans});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day08/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "4";
        const answer = try solve_1(allocator, input, 8);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day08/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "57";
        const answer = try solve_1(allocator, input, 32);
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
        var input = try Input.parse(allocator, "day08/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "21";
        const answer = try solve_2(allocator, input, 8);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day08/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "2922657";
        const answer = try solve_2(allocator, input, 256);
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
        var input = try Input.parse(allocator, "day08/input/input_3_sample.txt");
        defer input.deinit(allocator);

        const expected = "7";
        const answer = try solve_3(allocator, input, 8);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day08/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "2799";
        const answer = try solve_3(allocator, input, 256);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
