# JSX Fragment Compiler

POC JSX compiler written in Zig that automatically inserts fragments when needed, eliminating the need for manual top-level fragment wrapping.


https://github.com/user-attachments/assets/68c0929f-8f7f-4c8d-9fff-de3d096c99f4


## Overview

Warning def not prod ready!

## How It Works

The compiler has 4 stages:

1. **Lexer**: Breaks down the input code into an array list of tokens
   - Generates a token stream for parsing

2. **Parser**: Constructs an Abstract Syntax Tree (AST) from the token stream
   - Builds hierarchical representation of the code
   - Maintains JSX element relationships

3. **Preprocessor**: Performs code analysis and optimization
   - Detects scenarios requiring automatic fragment insertion
   - Prepares AST for code generation

4. **Code Generator**: Produces the final optimized output
   - Generates JavaScript with automatic fragments where needed
   - Maintains JSX semantics

## Example

```jsx
// Input: Mult

https://github.com/user-attachments/assets/56e3e8e6-6cac-477a-abcf-256c65826b81

iple elements without explicit fragment
<div>Hello</div>
<span>World</span>

// Output: Automatically wrapped with fragment
<>
  <div>Hello</div>
  <span>World</span>
</>
```

## Development

```bash
# Build the project
zig build

# Run tests (if available)
zig build test
```

## Future Possibilities

While this project is a proof-of-concept, similar techniques could be applied to:
- Smart fragment insertion in production JSX compilers
- Automated JSX optimizations
- Enhanced developer experience through intelligent compilation

## Contributing

This is an experimental project, but feel free to:
- Open issues for discussion
- Submit PRs for improvements
- Share ideas for JSX compilation optimization

## License
[MIT](LICENSE)
