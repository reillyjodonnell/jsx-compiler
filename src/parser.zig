const std = @import("std");
const lexer = @import("lexer.zig");

pub const NodeType = enum {
    JSX_ROOT_MARKER,
    JSX,
    JS,
    ROOT,
    STRING,
};

pub const Node = struct {
    // all nodes but the root have a parent
    parent: ?*Node,
    node_type: NodeType,
    value: ?[]const u8,
    children: std.ArrayList(*Node),
    kind: ?lexer.TagClosingState = null,
    closing_delimitter: ClosingDelimitter = ClosingDelimitter.NONE,
    need_comma: bool = false,
    need_quotes: bool = false,
    child_index: usize = 0,

    pub fn init(allocator: std.mem.Allocator, node_type: NodeType) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .parent = null,
            .node_type = node_type,
            .value = null,
            .children = std.ArrayList(*Node).init(allocator),
        };
        return node;
    }

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        for (self.children.items) |child| {
            child.deinit(allocator);
        }
        self.children.deinit();

        allocator.destroy(self);
    }

    pub fn dfsPrint(self: *Node, level: usize) void {
        for (self.children.items) |child| {
            child.dfsPrint(level + 1);
        }
    }
};

pub const JSXState = enum { NON_JSX, ROOT_JSX, NESTED_JSX };

pub const ClosingDelimitter = enum { NONE, CURLY_BRACE, SQUARE_BRACKET };

pub fn parser(allocator: std.mem.Allocator, token_stream: lexer.TokenList) !*Node {
    const root = try Node.init(allocator, NodeType.ROOT);
    var current_parent = root;
    var prev_sibling: ?*Node = null;
    var jsx_state = JSXState.NON_JSX;
    var tag_checksum: usize = 0;

    for (token_stream.tokens.items) |token| {
        if (token.tag_kind) |kind| {
            switch (kind) {
                .opening => {
                    tag_checksum += 1;
                    if (jsx_state == JSXState.NON_JSX) {
                        jsx_state = JSXState.ROOT_JSX;
                        const node = try Node.init(allocator, NodeType.JSX_ROOT_MARKER);
                        node.*.parent = current_parent;
                        node.*.value = "JSX_ROOT_MARKER";
                        node.*.kind = lexer.TagClosingState.opening;
                        try current_parent.children.append(node);
                        current_parent = node;
                    }

                    const node = try Node.init(allocator, NodeType.JSX);
                    node.*.parent = current_parent;
                    node.*.value = token.value;
                    node.*.kind = kind;
                    try current_parent.children.append(node);
                    current_parent = node;
                    jsx_state = JSXState.NESTED_JSX;
                },
                .closing => {
                    tag_checksum -= 1;
                    current_parent = if (current_parent.parent) |node| node else current_parent;
                    const node = try Node.init(allocator, NodeType.JSX);
                    node.*.parent = current_parent;
                    node.*.value = token.value;
                    node.*.kind = kind;
                    try current_parent.children.append(node);
                },
                else => {},
            }
            continue;
        }

        if (jsx_state == JSXState.NESTED_JSX and tag_checksum == 0) {
            // add the closing root marker
            const node = try Node.init(allocator, NodeType.JSX_ROOT_MARKER);
            node.*.parent = current_parent;
            node.*.value = "JSX_ROOT_MARKER";
            node.*.kind = lexer.TagClosingState.closing;
            try current_parent.children.append(node);
            current_parent = node;
            jsx_state = JSXState.NON_JSX;
        }

        const node = try Node.init(allocator, if (current_parent.node_type == NodeType.JSX) NodeType.STRING else NodeType.JS);
        node.*.parent = current_parent;
        node.*.value = token.value;
        node.*.need_quotes = jsx_state == JSXState.NESTED_JSX;
        try current_parent.children.append(node);

        prev_sibling = node;
    }

    return root;
}
