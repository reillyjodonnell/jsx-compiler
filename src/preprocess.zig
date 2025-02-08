const std = @import("std");
const parser = @import("parser.zig");
const lexer = @import("lexer.zig");

pub fn preprocess_jsx(ast: *parser.Node) !*parser.Node {
    const jsx_root_open = searchRootOpen(
        ast,
    );
    const jsx_root_close = searchRootClose(ast);

    if (jsx_root_open != null and jsx_root_close != null) {
        jsx_root_open.?.value = "FRAGMENT_OPENING";
        jsx_root_close.?.value = "FRAGMENT_CLOSING";

        // flag the children as needing commas
        for (jsx_root_open.?.children.items) |child| {
            child.need_comma = true;
        }
    }

    return ast;
}

fn searchRootOpen(node: *parser.Node) ?*parser.Node {
    if (node.node_type == parser.NodeType.JSX_ROOT_MARKER and
        node.kind.? == lexer.TagClosingState.opening and node.children.items.len > 1)
    {
        // We found the opening marker
        return node;
    }

    for (node.children.items) |child| {
        if (searchRootOpen(child)) |result| {
            return result;
        }
    }
    return null;
}

fn searchRootClose(node: *parser.Node) ?*parser.Node {
    if (node.node_type == parser.NodeType.JSX_ROOT_MARKER and
        node.kind.? == lexer.TagClosingState.closing)
    {
        // We found the opening marker
        return node;
    }

    for (node.children.items) |child| {
        if (searchRootClose(child)) |result| {
            return result;
        }
    }
    return null;
}
