const std = @import("std");
const parser = @import("parser.zig");
const lexer = @import("lexer.zig");

pub fn preprocess_jsx(allocator: std.mem.Allocator, ast: *parser.Node) !*parser.Node {
    const root_jsx_needs_fragment = search(ast);
    var updated_ast = ast;

    if (root_jsx_needs_fragment) |node| {
        // append to beginning of the parent's children array list a open fragment
        const open_fragment = try parser.Node.init(allocator, parser.NodeType.JSX);
        errdefer open_fragment.deinit(allocator); // Clean up if subsequent allocations fail
        open_fragment.*.parent = node.parent;
        open_fragment.*.value = "FRAGMENT_OPENING";
        open_fragment.*.kind = lexer.TagClosingState.opening;

        // append to end of the parent's children array list a closing fragment
        const close_fragment = try parser.Node.init(allocator, parser.NodeType.JSX);
        errdefer close_fragment.deinit(allocator); // Clean up if subsequent operations fail
        close_fragment.*.parent = node.parent;
        close_fragment.*.value = "FRAGMENT_CLOSING";
        close_fragment.*.kind = lexer.TagClosingState.closing;

        if (node.parent) |parent| {
            try parent.children.append(open_fragment);
            try parent.children.append(close_fragment);
        }
        updated_ast = open_fragment;
    }

    return updated_ast;
}

// Loop over the tree to find the root jsx
fn search(node: *parser.Node) ?*parser.Node {
    if (node.kind) |kind| {
        if (kind == lexer.TagClosingState.opening) {
            if (node.parent) |parent| {
                if (parent.children.items.len > 1) {
                    return parent;
                }
            }
        }
    }

    for (node.children.items) |child| {
        if (search(child)) |result| {
            return result;
        }
    }
    return null;
}
