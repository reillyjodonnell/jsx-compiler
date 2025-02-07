const std = @import("std");
const parser = @import("parser.zig");
const lexer = @import("lexer.zig");
pub fn code_gen(allocator: std.mem.Allocator, ast: *parser.Node) ![]const u8 {
    var code = std.ArrayList(u8).init(allocator);
    try code.appendSlice("import { jsx as _jsx } from \"react/jsx-runtime\"; ");
    defer code.deinit();

    try traverse_dfs(ast, &code, 1);

    // Return the owned slice
    return code.toOwnedSlice();
}

const State = enum {
    INSIDE_JSX,
};

const ASTError = error{UNEXPECTED_EMPTY_NODE_VALUE};

fn traverse_dfs(node: *parser.Node, text: *std.ArrayList(u8), layer: usize) !void {
    if (node.kind) |kind| {
        const value = node.value orelse return ASTError.UNEXPECTED_EMPTY_NODE_VALUE;

        switch (kind) {
            // if no node value throw an error
            lexer.TagClosingState.opening => {
                try text.writer().print("_jsx(\"{s}\",{{ children: ", .{value});
            },
            lexer.TagClosingState.closing => {
                try text.writer().print("}}) ", .{});
            },
            else => {},
        }
    } else if (node.value) |value| {
        try text.writer().print("{s} ", .{value});
    }

    for (node.children.items) |child| {
        try traverse_dfs(child, text, layer + 1);
    }
}
