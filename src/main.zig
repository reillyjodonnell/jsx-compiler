const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const code_gen = @import("code_generator.zig");
const preprocess = @import("preprocess.zig");
pub fn main() !void {
    var buffer: [200]u8 = undefined;
    const text = try std.fs.cwd().readFile("./app.jsx", &buffer);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit(); // Ensure cleanup
    const res = try compile_jsx(allocator, text);
    defer allocator.free(res);

    var file = try std.fs.cwd().createFile("compiled.jsx", .{});
    defer file.close();

    try file.writeAll(res);
}

const testing = std.testing;

test "simple test" {
    var buffer: [200]u8 = undefined;
    const text = try std.fs.cwd().readFile("./app.jsx", &buffer);
    const test_allocator = std.testing.allocator;
    const res = try compile_jsx(test_allocator, text);
    const expected =
        \\import { jsx as _jsx } from "react/jsx-runtime"; import React from 'react'; export function App() { return ( _jsx("div",{ children: _jsx("h1",{ children: App }) }) ); } 
    ;
    defer test_allocator.free(res);

    try testing.expectEqualStrings(res, expected);
}

// caller be sure to call free on the result
// i.e. allocator.free(res);
fn compile_jsx(allocator: std.mem.Allocator, code: []const u8) ![]const u8 {
    var tokens = try lexer.lexer(allocator, code);
    defer tokens.deinit();

    var root_ast = try parser.parser(allocator, tokens);
    defer root_ast.deinit(allocator);

    const preprocessed_ast = try preprocess.preprocess_jsx(root_ast);
    const res = try code_gen.code_gen(allocator, preprocessed_ast);

    std.debug.print("\n\n🟢 compiled code: {s}\n\n", .{res});

    root_ast.dfsPrint(1);

    return res;
}
