const std = @import("std");
const parser = @import("parser.zig");
const lexer = @import("lexer.zig");
pub fn code_gen(allocator: std.mem.Allocator, ast: *parser.Node) ![]const u8 {
    var code = std.ArrayList(u8).init(allocator);
    defer code.deinit();

    var ctx = Ctx{
        .layer = 1,
        .text = &code,
        .use_jsx = false,
        .use_jsxs = false,
        .use_fragment = false,
    };

    try traverse_dfs(
        &ctx,
        ast,
        allocator,
    );

    var imports = std.ArrayList(u8).init(allocator);
    defer imports.deinit();

    try imports.appendSlice("import { ");
    if (ctx.use_jsx) try imports.appendSlice("jsx as _jsx, ");
    if (ctx.use_jsxs) try imports.appendSlice("jsxs as _jsxs, ");
    if (ctx.use_fragment) try imports.appendSlice("Fragment as _Fragment, ");
    try imports.appendSlice("} from \"react/jsx-runtime\"; ");

    try code.insertSlice(0, imports.items);

    // Return the owned slice
    return code.toOwnedSlice();
}

const Ctx =
    struct {
    layer: usize,
    text: *std.ArrayList(u8),
    use_jsx: bool,
    use_jsxs: bool,
    use_fragment: bool,
};

const ASTError = error{UNEXPECTED_EMPTY_NODE_VALUE};

fn traverse_dfs(ctx: *Ctx, node: *parser.Node, allocator: std.mem.Allocator) !void {
    if (node.kind) |kind| {
        const value = node.value orelse return ASTError.UNEXPECTED_EMPTY_NODE_VALUE;
        switch (kind) {
            // if no node value throw an error
            lexer.TagClosingState.opening => {
                if (std.mem.eql(u8, value, "FRAGMENT_OPENING")) {
                    ctx.use_fragment = true;
                    try ctx.text.writer().print("_jsxs(_Fragment, {{children: [", .{});
                } else {
                    var content_children: usize = 0;
                    for (node.children.items) |child| {
                        // only count children with open tags OR strings
                        if (child.kind) |k| {
                            if (k == lexer.TagClosingState.opening) {
                                content_children += 1;
                            }
                        } else if (child.value != null) {
                            content_children += 1;
                        }
                    }
                    if (content_children > 1) {
                        ctx.use_jsxs = true;
                        try ctx.text.writer().print("_jsxs(\"{s}\",{{ children: [", .{value});
                    }

                    if (content_children == 1) {
                        ctx.use_jsx = true;
                        try ctx.text.writer().print("_jsx(\"{s}\",{{ children: ", .{value});
                    }
                }
                // check the number of children this has
            },
            lexer.TagClosingState.closing => {
                if (std.mem.eql(u8, "FRAGMENT_CLOSING", value)) {
                    try ctx.text.writer().print("]}}) ", .{});
                } else {
                    try ctx.text.writer().print("}}) ", .{});
                }
                // check if this is the last sibling
                if (node.need_comma and !std.mem.eql(u8, "FRAGMENT_CLOSING", value)) {
                    try ctx.text.writer().print(", ", .{});
                }
            },
            else => {},
        }
    } else if (node.value) |value| {
        if (node.need_quotes) {
            try ctx.text.writer().print("\"{s}\" ", .{value});
        } else {
            try ctx.text.writer().print("{s} ", .{value});
        }
    }

    for (node.children.items) |child| {
        try traverse_dfs(ctx, child, allocator);
    }
}
