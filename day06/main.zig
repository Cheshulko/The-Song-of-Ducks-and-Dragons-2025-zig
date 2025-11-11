const std = @import("std");

const Input = struct {
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

        return Input{ .file_content = file_content };
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
        2 => solve_2(allocator, input),
        3 => solve_3(allocator, input, 1000, 1000),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

const Mentors = "ABCD";
const Novices = "abcd";

fn solve_1(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const answer = count('A', 'a', 1, std.math.maxInt(usize), input.file_content);

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    var answer: usize = 0;
    for (Mentors, Novices) |M, N| {
        answer += count(M, N, 1, std.math.maxInt(usize), input.file_content);
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input, repeat: usize, distance: usize) ![]const u8 {
    var answer: usize = 0;

    for (Mentors, Novices) |M, N| {
        answer += count(M, N, repeat, distance, input.file_content);
    }

    const slice = reverse(input.file_content[0..]);
    for (Mentors, Novices) |M, N| {
        answer += count(M, N, repeat, distance, slice);
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn count(M: u8, N: u8, repeat: usize, distance: usize, slice: []u8) usize {
    const L: usize = slice.len;

    var right_ind: usize = 0;
    var left_ind: usize = 0;
    var cnt: usize = 0;
    var answer: usize = 0;

    while (true) {
        while (@divFloor(right_ind, L) < repeat and slice[@rem(right_ind, L)] != N) {
            if (slice[@rem(right_ind, L)] == M) {
                cnt += 1;
            }
            right_ind += 1;
        }

        while (left_ind < right_ind and right_ind - left_ind > distance) {
            if (slice[@rem(left_ind, L)] == M) {
                cnt -= 1;
            }
            left_ind += 1;
        }

        if (@divFloor(right_ind, L) == repeat) {
            break;
        }

        answer += cnt;
        right_ind += 1;
    }

    return answer;
}

fn reverse(slice: []u8) []u8 {
    var i: usize = 0;
    var j: usize = slice.len - 1;

    while (i < j) : (i += 1) {
        const tmp = slice[i];
        slice[i] = slice[j];
        slice[j] = tmp;

        j -= 1;
    }

    return slice;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day06/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "5";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day06/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "154";
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
        var input = try Input.parse(allocator, "day06/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "11";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day06/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "3931";
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
        var input = try Input.parse(allocator, "day06/input/input_3_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "34";
        const answer = try solve_3(allocator, input, 1, 10);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day06/input/input_3_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "72";
        const answer = try solve_3(allocator, input, 2, 10);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day06/input/input_3_sample_3.txt");
        defer input.deinit(allocator);

        const expected = "3442321";
        const answer = try solve_3(allocator, input, 1000, 1000);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day06/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "1667828965";
        const answer = try solve_3(allocator, input, 1000, 1000);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
