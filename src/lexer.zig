const std = @import("std");

pub const TokenList = struct {
    tokens: std.ArrayList(Token),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !TokenList {
        return .{
            .tokens = std.ArrayList(Token).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TokenList) void {
        for (self.tokens.items) |token| {
            self.allocator.free(token.value);
        }
        self.tokens.deinit();
    }
};

fn getTagType(tag: []const u8) ?TagType {
    const tags = std.StaticStringMap(TagType).initComptime(.{
        .{ "div", .div },
        .{ "h1", .h1 },
    });

    return tags.get(tag);
}

const TagType = enum { div, h1, p, custom };
pub const TagClosingState = enum { opening, closing, self_closing };

pub const Token = struct {
    tag_type: ?TagType,
    tag_kind: ?TagClosingState,
    value: []const u8,
    line_number: u32,
    column_number: u32,
};

const TokenizerState = enum {
    JS,
    JSX,
    HTML_OPEN,
    HTML_CLOSE,
};

const TokenizerConfig = struct {
    allocator: std.mem.Allocator,
    ignore_whitespace: bool = true,
    ignore_comments: bool = true,

    // state
    line_number: u32 = 0,
    column_number: u32 = 0,
    state: TokenizerState = .JS,
};

pub fn lexer(allocator: std.mem.Allocator, text: []const u8) !TokenList {
    var token_list = try TokenList.init(allocator);
    var config = TokenizerConfig{ .allocator = allocator };

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    for (text) |value| {
        switch (value) {
            '\n' => {
                if (buffer.items.len > 0) {
                    // copy the contents of the buffer into the token
                    const token_val = try allocator.dupe(u8, buffer.items);
                    const token = Token{
                        .tag_type = null,
                        .value = token_val,
                        .line_number = config.line_number,
                        .column_number = config.column_number,
                        .tag_kind = if (config.state == TokenizerState.HTML_CLOSE) TagClosingState.closing else if (config.state == TokenizerState.HTML_OPEN) TagClosingState.opening else null,
                    };
                    try token_list.tokens.append(token);
                    // clear the mem of buffer
                    buffer.clearRetainingCapacity();
                }
                config.line_number += 1;
                config.column_number = 0;
            },
            ' ', '\t' => {
                if (buffer.items.len > 0) {
                    // copy the contents of the buffer into the token
                    const token_val = try allocator.dupe(u8, buffer.items);
                    const token = Token{
                        .tag_type = null,
                        .value = token_val,
                        .line_number = config.line_number,
                        .column_number = config.column_number,
                        .tag_kind = if (config.state == TokenizerState.HTML_CLOSE) TagClosingState.closing else if (config.state == TokenizerState.HTML_OPEN) TagClosingState.opening else null,
                    };
                    try token_list.tokens.append(token);
                    // clear the mem of buffer
                    buffer.clearRetainingCapacity();
                }
                config.column_number += 1;
                continue;
            },
            '<' => {
                if (buffer.items.len > 0) {
                    const token_val = try allocator.dupe(u8, buffer.items);
                    const token = Token{
                        .value = token_val,
                        .line_number = config.line_number,
                        .column_number = config.column_number,
                        .tag_type = getTagType(token_val),
                        .tag_kind = if (config.state == TokenizerState.HTML_CLOSE) TagClosingState.closing else if (config.state == TokenizerState.HTML_OPEN) TagClosingState.opening else null,
                    };
                    try token_list.tokens.append(token);
                    buffer.clearRetainingCapacity();
                }
                config.state = .HTML_OPEN;
                try buffer.append(value);
                config.column_number += 1;
            },
            '/' => {
                // it's either a closing tag or comment

                // check the state to see if we're in the middle of a tag
                if (config.state == .HTML_OPEN) {
                    // it's a closing tag
                    config.state = .HTML_CLOSE;
                }
                config.column_number += 1;
            },
            '>' => {
                const slice = buffer.items[1..]; // Get the slice you want

                const token_val = try allocator.dupe(u8, slice);
                const token = Token{
                    .value = token_val,
                    .line_number = config.line_number,
                    .column_number = config.column_number,
                    .tag_type = getTagType(token_val),
                    .tag_kind = if (config.state == TokenizerState.HTML_CLOSE) TagClosingState.closing else if (config.state == TokenizerState.HTML_OPEN) TagClosingState.opening else null,
                };
                config.state = .JS;
                try token_list.tokens.append(token);
                buffer.clearRetainingCapacity();
                config.column_number += 1;
            },
            else => {
                try buffer.append(value);
                config.column_number += 1;
            },
        }
    }

    return token_list;
}
