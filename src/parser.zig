const std = @import("std");
const lexer = @import("lexer.zig");

pub const NodeType = enum {
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
        std.debug.print("at depth: {d}, node type: {any} value: {?s} \n", .{ level, self.node_type, self.value });
        for (self.children.items) |child| {
            child.dfsPrint(level + 1);
        }
    }
};

pub const ClosingDelimitter = enum { NONE, CURLY_BRACE, SQUARE_BRACKET };

pub fn parser(allocator: std.mem.Allocator, token_stream: lexer.TokenList) !*Node {
    const root = try Node.init(allocator, NodeType.ROOT);
    var current_parent = root;
    var prev_sibling: ?*Node = null;

    for (token_stream.tokens.items) |token| {
        if (prev_sibling) |sibling| {
            if (sibling.value) |value| {
                if (std.mem.eql(u8, value, "return") and std.mem.eql(u8, token.value, "(")) continue;
            }
        }

        if (token.tag_kind) |kind| {
            switch (kind) {
                .opening => {
                    const node = try Node.init(allocator, NodeType.JSX);
                    node.*.parent = current_parent;
                    node.*.value = token.value;
                    node.*.kind = kind;
                    try current_parent.children.append(node);
                    current_parent = node;
                },
                .closing => {
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

        const node = try Node.init(allocator, if (current_parent.node_type == NodeType.JSX) NodeType.STRING else NodeType.JS);
        node.*.parent = current_parent;
        node.*.value = token.value;
        try current_parent.children.append(node);
        prev_sibling = node;
    }

    return root;
}
