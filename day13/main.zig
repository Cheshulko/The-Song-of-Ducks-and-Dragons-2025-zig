const std = @import("std");

const Range = struct {
    l: usize,
    r: usize,

    fn get_size(self: *const Range) usize {
        return self.r - self.l + 1;
    }
};

const Cell = union(enum) {
    Number: usize,
    Segment: Range,

    fn get_number(self: *const Cell) ?usize {
        return switch (self.*) {
            .Number => |n| n,
            .Segment => |_| null,
        };
    }

    fn get_segment(self: *const Cell) ?Range {
        return switch (self.*) {
            .Number => |_| null,
            .Segment => |s| s,
        };
    }
};

const Input = struct {
    file_content: []const u8,
    numbers: std.ArrayList(Cell),

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

        var numbers: std.ArrayList(Cell) = .empty;
        errdefer numbers.deinit(allocator);

        var it = std.mem.splitScalar(u8, file_content, '\n');
        while (it.next()) |number_str| {
            if (std.fmt.parseInt(usize, number_str, 10)) |value| {
                try numbers.append(allocator, Cell{ .Number = value });
            } else |_| {
                var it_number = std.mem.splitScalar(u8, number_str, '-');
                const l = it_number.next().?;
                const r = it_number.next().?;

                try numbers.append(allocator, Cell{ .Segment = Range{
                    .l = try std.fmt.parseInt(usize, l, 10),
                    .r = try std.fmt.parseInt(usize, r, 10),
                } });
            }
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
        1 => solve_1(allocator, input),
        2 => solve_2(allocator, input, 20252025),
        3 => solve_2(allocator, input, 202520252025),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };
    defer allocator.free(answer);

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    const n = input.numbers.items.len;
    const r = @rem(2025, 1 + n);
    const hn = @divFloor(n + 1, 2);

    const answer =
        if (r == 0) 1 else if (r <= hn) input.numbers.items[2 * (r - 1)].get_number().? else input.numbers.items[1 + 2 * (n - r)].get_number().?;
    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

fn solve_2(allocator: std.mem.Allocator, input: Input, turns: usize) ![]const u8 {
    const n = input.numbers.items.len;

    var sum: usize = 0;
    for (input.numbers.items) |cell| {
        sum += cell.get_segment().?.get_size();
    }

    std.debug.assert(@rem(turns, 1 + sum) > 0);
    const r = @rem(turns, 1 + sum) - 1;

    var forward = true;
    var size: usize = 0;
    var i: usize = 0;
    while (true) {
        const next_size = input.numbers.items[i].get_segment().?.get_size();
        if (size + next_size > r) break;

        size += next_size;

        if (forward) {
            if (i + 2 < n) {
                i += 2;
            } else {
                forward = false;
                i = n - 1 - @rem(n, 2);
            }
        } else {
            i -= 2;
        }
    }

    const seg = input.numbers.items[i].get_segment().?;
    const left = r - size;
    const answer = if (forward) seg.l + left else seg.r - left;
    const result = try std.fmt.allocPrint(allocator, "{}", .{answer});

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day13/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "67";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day13/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "941";
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
        var input = try Input.parse(allocator, "day13/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "30";
        const answer = try solve_2(allocator, input, 20252025);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day13/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "6085";
        const answer = try solve_2(allocator, input, 20252025);
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
        var input = try Input.parse(allocator, "day13/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "85279";
        const answer = try solve_2(allocator, input, 202520252025);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
