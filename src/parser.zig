const std = @import("std");
const lexer = @import("lexer.zig");

const NodeType = enum {
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

pub fn parser(allocator: std.mem.Allocator, token_stream: lexer.TokenList) !*Node {
    const root = try Node.init(allocator, NodeType.ROOT);
    var current_parent = root;

    for (token_stream.tokens.items) |token| {
        std.debug.print("processing value: {s} kind: {any} \n", .{ token.value, token.tag_kind });
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
        } else {
            const node = try Node.init(allocator, if (current_parent.node_type == NodeType.JSX) NodeType.STRING else NodeType.JS);
            node.*.parent = current_parent;
            node.*.value = token.value;
            try current_parent.children.append(node);
        }
    }

    return root;
}
