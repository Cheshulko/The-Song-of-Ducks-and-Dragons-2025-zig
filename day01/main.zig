const std = @import("std");

const Input = struct {
    names: std.ArrayList([]const u8),
    instructions: std.ArrayList([]const u8),
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

        var names: std.ArrayList([]const u8) = .empty;
        var instructions: std.ArrayList([]const u8) = .empty;

        errdefer allocator.free(file_content);
        errdefer names.deinit(allocator);
        errdefer instructions.deinit(allocator);

        var it = std.mem.splitSequence(u8, file_content, "\n\n");

        const names_slice = it.next().?;
        var it_names = std.mem.splitScalar(u8, names_slice, ',');
        while (it_names.next()) |line| {
            try names.append(allocator, line);
        }

        const instructions_slice = it.next().?;
        var it_instructions = std.mem.splitScalar(u8, instructions_slice, ',');
        while (it_instructions.next()) |line| {
            try instructions.append(allocator, line);
        }

        return Input{
            .names = names,
            .instructions = instructions,
            .file_content = file_content,
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        self.names.deinit(allocator);
        self.instructions.deinit(allocator);
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
        1 => solve_1(input),
        2 => solve_2(input),
        3 => solve_3(input),
        else => @panic("Unknown part. Available parts: 1, 2, 3."),
    };

    std.debug.print("Answer: {s}\n", .{answer});
}

fn solve_1(input: Input) ![]const u8 {
    const names_cnt: i16 = @as(i16, @intCast(input.names.items.len));

    var pos: i16 = 0;
    for (input.instructions.items) |instruction| {
        const dir: u8 = instruction[0];
        const len: i16 = try std.fmt.parseInt(i16, instruction[1..], 10);
        switch (dir) {
            'R' => pos = @min(pos + len, names_cnt - 1),
            'L' => pos = @max(pos - len, 0),
            else => unreachable,
        }
    }

    return input.names.items[@intCast(pos)];
}

fn solve_2(input: Input) ![]const u8 {
    const names_cnt: i16 = @as(i16, @intCast(input.names.items.len));

    var pos: i16 = 0;
    for (input.instructions.items) |instruction| {
        const dir: u8 = instruction[0];
        const len: i16 = try std.fmt.parseInt(i16, instruction[1..], 10);
        switch (dir) {
            'R' => pos = @rem(pos + len, names_cnt),
            'L' => pos = @rem(names_cnt + @rem(pos - len, names_cnt), names_cnt),
            else => unreachable,
        }
    }

    return input.names.items[@intCast(pos)];
}

fn solve_3(input: Input) ![]const u8 {
    const names_cnt: i16 = @as(i16, @intCast(input.names.items.len));

    var pos_to_swap: i16 = 0;
    for (input.instructions.items) |instruction| {
        const dir: u8 = instruction[0];
        const len: i16 = try std.fmt.parseInt(i16, instruction[1..], 10);
        switch (dir) {
            'R' => pos_to_swap = @rem(len, names_cnt),
            'L' => pos_to_swap = @rem(names_cnt + @rem(-len, names_cnt), names_cnt),
            else => unreachable,
        }

        const temp = input.names.items[0];
        input.names.items[0] = input.names.items[@intCast(pos_to_swap)];
        input.names.items[@intCast(pos_to_swap)] = temp;
    }

    return input.names.items[0];
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day01/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "Fyrryn";
        const answer = try solve_1(input);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day01/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "Azalar";
        const answer = try solve_1(input);
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
        var input = try Input.parse(allocator, "day01/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "Elarzris";
        const answer = try solve_2(input);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day01/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "Urithjor";
        const answer = try solve_2(input);
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
        var input = try Input.parse(allocator, "day01/input/input_3_sample.txt");
        defer input.deinit(allocator);

        const expected = "Drakzyph";
        const answer = try solve_3(input);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day01/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "Arvgoril";
        const answer = try solve_3(input);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
