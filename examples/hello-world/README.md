# Hello World Example

This is a simple Rust application that demonstrates bundling assets with the Rust Bundler GitHub Action.

## What it does

The application reads a text file from the `assets/` directory and prints its contents to the console. This demonstrates that the bundler correctly includes additional files and folders alongside the binary.

## Structure

```
hello-world/
├── Cargo.toml          # Rust project configuration
├── src/
│   └── main.rs         # Application source code
├── assets/
│   └── hello.txt       # Text file containing "Hello World"
└── README.md           # This file
```

## Building

```bash
cargo build --release
```

## Running

After building, you can run the application:

```bash
./target/release/hello-world
```

## Bundling

This example is used by the CI workflow to test that the Rust Bundler action correctly:
1. Creates platform-specific bundles (Linux tar.gz, Windows zip, macOS .app)
2. Includes the assets/ folder in the bundle
3. The bundled application can successfully read files from the assets/ folder

The CI workflow tests this on Linux, Windows, and macOS platforms.
