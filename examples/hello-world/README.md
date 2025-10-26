# Hello World Example

This is a simple Rust application that demonstrates bundling assets with the Rust Bundler GitHub Action.

## What it does

The application reads a text file from the `assets/` directory and prints its contents to the console. This demonstrates that the bundler correctly includes additional files and folders alongside the binary.

## Structure

```
hello-world/
├── Cargo.toml          # Rust project configuration
├── build.rs            # Build script (example for Windows resource embedding)
├── src/
│   └── main.rs         # Application source code
├── assets/
│   └── hello.txt       # Text file containing "Hello World"
├── icon.png            # Application icon
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

## Windows Resource Embedding

The `build.rs` file embeds icons and metadata into Windows executables at build time using the `winres` crate.

The project includes `winres = "0.1"` in `[build-dependencies]`, which automatically reads metadata from `Cargo.toml` (name, version, description, authors) and embeds it into the Windows executable.

To add an icon:
1. Convert the PNG icon to ICO format:
   ```bash
   convert icon.png -define icon:auto-resize=256,128,96,64,48,32,16 icon.ico
   ```

2. Rebuild the project - the `build.rs` will automatically detect and use `icon.ico` if it exists

## Metadata

The bundler automatically extracts and uses the following fields from `Cargo.toml`:
- `readme` - Automatically includes README.md in the bundle
- `license-file` - Automatically includes LICENSE in the bundle
- Package metadata (name, version, description, authors) for platform-specific metadata files

## Bundling

This example is used by the CI workflow to test that the Rust Bundler action correctly:
1. Creates platform-specific bundles (Linux tar.gz, Windows zip, macOS .app)
2. Includes the assets/ folder in the bundle
3. The bundled application can successfully read files from the assets/ folder

The CI workflow tests this on Linux, Windows, and macOS platforms.
