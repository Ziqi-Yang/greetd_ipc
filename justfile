readme:
    pandoc -o ./README.md ./README.typ

build-example:
    zig build -Dexample=examples/demo.zig build-example

run-example:
    zig build -Dexample=examples/demo.zig run-example

run: build-example
    fakegreet ./zig-out/bin/demo
