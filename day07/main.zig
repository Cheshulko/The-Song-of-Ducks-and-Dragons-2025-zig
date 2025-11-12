const std = @import("std");

const Alphabet_Length = 28 * 2;
const Max_Length = 11;
const Min_Length = 7;

fn u8_to_index(c: u8) usize {
    return @as(usize, if (c <= 'Z') c - 'A' else c - 'a' + 1 + 'Z' - 'A');
}

const Input = struct {
    file_content: []u8,
    names: std.ArrayList([]const u8),
    rules: [Alphabet_Length]std.ArrayList(usize),

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

        var it = std.mem.splitSequence(u8, file_content, "\n\n");

        const names_str = it.next().?;
        var names_it = std.mem.splitScalar(u8, names_str, ',');
        var names: std.ArrayList([]const u8) = .empty;
        errdefer names.deinit(allocator);
        while (names_it.next()) |name| {
            try names.append(allocator, name);
        }

        var rules: [Alphabet_Length]std.ArrayList(usize) = undefined;
        for (0..Alphabet_Length) |i| {
            rules[i] = std.ArrayList(usize).empty;
            errdefer rules[i].deinit(allocator);
        }
        const rules_str = it.next().?;
        var rules_it = std.mem.splitScalar(u8, rules_str, '\n');
        while (rules_it.next()) |rule| {
            var rule_it = std.mem.splitSequence(u8, rule, " > ");
            const from_c = rule_it.next().?[0];
            const from = u8_to_index(from_c);

            const tos_str = rule_it.next().?;
            var tos_it = std.mem.splitScalar(u8, tos_str, ',');
            while (tos_it.next()) |to_str| {
                const to_c = to_str[0];
                const to = u8_to_index(to_c);

                try rules[from].append(allocator, to);
            }
        }

        return Input{
            .file_content = file_content,
            .names = names,
            .rules = rules,
        };
    }

    pub fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.file_content);
        self.names.deinit(allocator);
        for (0..Alphabet_Length) |i| {
            self.rules[i].deinit(allocator);
        }
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

fn dfs(input: *const Input, name: []const u8, c: usize) bool {
    const nc = u8_to_index(name[0]);
    if (nc != c) {
        return false;
    }
    const rest = name[1..];
    if (rest.len == 0) {
        return true;
    }

    var can: bool = false;
    for (input.rules[c].items) |to| {
        can = can or dfs(input, rest, to);
    }

    return can;
}

fn dfs_count(
    allocator: std.mem.Allocator,
    input: *const Input,
    cur: *std.ArrayList(usize),
    unique: *std.AutoHashMap(u64, void),
) !void {
    const l = cur.items.len;
    const c = cur.items[l - 1];

    if (l >= Min_Length) {
        if (l <= Max_Length) {
            const ptr: [*]const u8 = @ptrCast(cur.items.ptr);
            const byte_len = cur.items.len * @sizeOf(usize);
            const bytes: []const u8 = ptr[0..byte_len];
            const hash = std.hash.Wyhash.hash(0, bytes);

            try unique.put(hash, {});
        } else {
            return;
        }
    }

    for (input.rules[c].items) |to| {
        try cur.append(allocator, to);
        try dfs_count(allocator, input, cur, unique);
        _ = cur.pop().?;
    }
}

fn solve_1(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    for (input.names.items) |name| {
        if (dfs(&input, name, u8_to_index(name[0]))) {
            const name_copy = try allocator.alloc(u8, name.len);
            @memcpy(name_copy, name);

            return name_copy;
        }
    }

    unreachable;
}

fn solve_2(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    var sum: usize = 0;
    for (input.names.items, 1..) |name, i| {
        if (dfs(&input, name, u8_to_index(name[0]))) {
            sum += i;
        }
    }

    const result = try std.fmt.allocPrint(allocator, "{}", .{sum});

    return result;
}

fn solve_3(allocator: std.mem.Allocator, input: Input) ![]const u8 {
    var unique = std.AutoHashMap(u64, void).init(allocator);
    defer unique.deinit();

    for (input.names.items) |name| {
        if (dfs(&input, name, u8_to_index(name[0]))) {
            var name_arr: std.ArrayList(usize) = .empty;
            defer name_arr.deinit(allocator);

            for (name) |c| {
                try name_arr.append(allocator, u8_to_index(c));
            }

            try dfs_count(allocator, &input, &name_arr, &unique);
        }
    }

    const result = try std.fmt.allocPrint(
        allocator,
        "{}",
        .{unique.count()},
    );

    return result;
}

test "Part 1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    {
        var input = try Input.parse(allocator, "day07/input/input_1_sample.txt");
        defer input.deinit(allocator);

        const expected = "Oroneth";
        const answer = try solve_1(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day07/input/input_1.txt");
        defer input.deinit(allocator);

        const expected = "Nyjorath";
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
        var input = try Input.parse(allocator, "day07/input/input_2_sample.txt");
        defer input.deinit(allocator);

        const expected = "23";
        const answer = try solve_2(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day07/input/input_2.txt");
        defer input.deinit(allocator);

        const expected = "2909";
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
        var input = try Input.parse(allocator, "day07/input/input_3_sample_1.txt");
        defer input.deinit(allocator);

        const expected = "25";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
    {
        var input = try Input.parse(allocator, "day07/input/input_3_sample_2.txt");
        defer input.deinit(allocator);

        const expected = "1154";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }

    {
        var input = try Input.parse(allocator, "day07/input/input_3.txt");
        defer input.deinit(allocator);

        const expected = "3383049";
        const answer = try solve_3(allocator, input);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, expected)) {
            std.debug.print("❌\nExpected: {s}\nFound:    {s}\n", .{ expected, answer });
            try std.testing.expect(false);
        }
    }
}
