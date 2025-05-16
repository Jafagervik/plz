const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const shell = env_map.get("SHELL") orelse "/bin/bash";
    const home = env_map.get("HOME") orelse getHomeDirectory();

    const history_file = blk: {
        if (std.mem.endsWith(u8, shell, "zsh")) {
            break :blk try std.fs.path.join(allocator, &[_][]const u8{ home, ".zsh_history" });
        } else { // Default to Bash
            break :blk try std.fs.path.join(allocator, &[_][]const u8{ home, ".bash_history" });
        }
    };
    defer allocator.free(history_file);

    const last_command = try getLastCommand(allocator, history_file, std.mem.endsWith(u8, shell, "zsh"));
    defer allocator.free(last_command);

    if (last_command.len == 0) {
        std.debug.print("No previous command found.\n", .{});
        std.posix.exit(1);
    }

    var child = std.process.Child.init(&[_][]const u8{ "sudo", last_command }, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    _ = try child.wait();
}

fn getLastCommand(allocator: std.mem.Allocator, history_file: []const u8, is_zsh: bool) ![]u8 {
    const file = std.fs.openFileAbsolute(history_file, .{ .mode = .read_only }) catch |err| {
        std.debug.print("Failed to open history file: {}\n", .{err});
        return allocator.dupe(u8, "");
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10Mb max
    defer allocator.free(content);

    var lines = std.mem.splitBackwardsScalar(u8, content, '\n');
    var last_line: ?[]const u8 = null;

    var found = false; // Find the second last non-empty line
    while (lines.next()) |line| {
        if (line.len > 0) {
            if (!found) {
                found = true;
            } else {
                last_line = line;
                break;
            }
        }
    }

    if (last_line == null) {
        return allocator.dupe(u8, "");
    }

    if (is_zsh) {
        // Zsh history format: : <timestamp>:0;<command>
        var parts = std.mem.splitAny(u8, last_line.?, ";");
        _ = parts.next(); // Skip timestamp
        if (parts.next()) |cmd| {
            return allocator.dupe(u8, std.mem.trim(u8, cmd, " \t"));
        }
        return allocator.dupe(u8, "");
    } else { // Bash
        return allocator.dupe(u8, std.mem.trim(u8, last_line.?, " \t"));
    }
}

fn getHomeDirectory() []const u8 {
    return "";
}
