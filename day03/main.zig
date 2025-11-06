const std = @import("std");

const Input = struct {
    numbers: std.ArrayList(i32),
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

        var numbers: std.ArrayList(i32) = .empty;
        errdefer numbers.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, ',');
        while (it.next()) |line| {
            try numbers.append(allocator, try std.fmt.parseInt(i32, line, 10));
        }

        return Input{ .numbers = numbers, .file_content = file_content };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        self.numbers.deinit(allocator);
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
    std.sort.block(i32, input.numbers.items, {}, comptime std.sort.asc(i32));

    var cur: i32 = input.numbers.items[0];
    var ans: i32 = cur;
    for (input.numbers.items) |number| {
        if (number > cur) {
            ans += number;
            cur = number;
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{ans});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const size: usize = 20;

    std.sort.block(i32, input.numbers.items, {}, comptime std.sort.asc(i32));

    var cur: i32 = input.numbers.items[0];
    var ans: i32 = cur;
    var cnt: usize = 1;
    for (input.numbers.items) |number| {
        if (number > cur) {
            ans += number;
            cur = number;
            cnt += 1;
        }
        if (cnt == size) {
            break;
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{ans});

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    std.sort.block(i32, input.numbers.items, {}, comptime std.sort.asc(i32));

    var sets: std.ArrayList(i32) = .empty;
    defer sets.deinit(allocator);

    for (input.numbers.items) |number| {
        var found_ind: usize = 0;
        for (sets.items, 0..) |last_in_set, ind| {
            if (last_in_set < number) {
                found_ind = ind + 1;
                break;
            }
        }

        if (found_ind == 0) {
            try sets.append(allocator, number);
        } else {
            sets.items[found_ind - 1] = number;
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{sets.items.len});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day03/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "29";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day03/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "2701";
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
        var input = try Input.parse(allocator, "day03/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "781";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day03/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "257";
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
        var input = try Input.parse(allocator, "day03/input/input_3_sample.txt");
        defer input.deinit(allocator);

        const expected = "3";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day03/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "3016";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
