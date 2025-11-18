const std = @import("std");

const Input = struct {
    file_content: []const u8,
    columns: std.ArrayList(usize),

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

        var columns: std.ArrayList(usize) = .empty;
        errdefer columns.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |column| {
            try columns.append(allocator, try std.fmt.parseInt(usize, column, 10));
        }

        return Input{
            .file_content = file_content,
            .columns = columns,
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.columns.deinit(allocator);
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

fn phase_1(columns: *std.ArrayList(usize)) bool {
    const columns_cnt = columns.items.len;

    var j: usize = 1;
    var any = false;
    while (j < columns_cnt) : (j += 1) {
        if (columns.items[j - 1] > columns.items[j]) {
            any = true;
            columns.items[j - 1] -= 1;
            columns.items[j] += 1;
        }
    }

    return any;
}

fn phase_2(columns: *std.ArrayList(usize)) bool {
    const columns_cnt = columns.items.len;

    var j: usize = 1;
    var any = false;
    while (j < columns_cnt) : (j += 1) {
        if (columns.items[j] > columns.items[j - 1]) {
            any = true;
            columns.items[j] -= 1;
            columns.items[j - 1] += 1;
        }
    }

    return any;
}

fn solve_1(allocator: std.mem.Allocator, input: Input, rounds: usize) ![]const u8 {
    var input_mut = input;

    const columns: *std.ArrayList(usize) = &input_mut.columns;
    var round: usize = 0;
    while (round < rounds) : (round += 1) {
        if (!phase_1(columns)) {
            break;
        }
    }
    while (round < rounds) : (round += 1) {
        if (!phase_2(columns)) {
            break;
        }
    }

    var answer: usize = 0;
    for (input_mut.columns.items, 1..) |column, ind| {
        answer += column * ind;
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});
    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    var input_mut = input;

    const columns: *std.ArrayList(usize) = &input_mut.columns;
    var round: usize = 0;
    while (phase_1(columns)) : (round += 1) {}
    while (phase_2(columns)) : (round += 1) {}

    const result = try std.fmt.allocPrint(allocator, "{}", .{round});
    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    var input_mut = input;

    const columns: *std.ArrayList(usize) = &input_mut.columns;
    const n: i64 = @intCast(columns.items.len);

    // the input is sorted ;/
    var avg: i64 = 0;
    for (columns.items) |column| {
        avg += @intCast(column);
    }
    avg = @divFloor(avg, n);

    var rounds: i64 = 0;
    for (columns.items) |column| {
        rounds += @max(0, (avg - @as(i64, @intCast(column))));
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{rounds});
    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day11/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "109";
        const answer = try solve_1(allocator, input, 10);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day11/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "271";
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
        var input = try Input.parse(allocator, "day11/input/input_2_sample_1.txt");
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
        var input = try Input.parse(allocator, "day11/input/input_2_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "1579";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day11/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "3211666";
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
        var input = try Input.parse(allocator, "day11/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "128430361125971";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
