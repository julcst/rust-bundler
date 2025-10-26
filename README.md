# Rust Bundler

[![GitHub release](https://img.shields.io/github/v/release/julcst/rust-bundler)](https://github.com/julcst/rust-bundler/releases)
[![GitHub marketplace](https://img.shields.io/badge/marketplace-rust--bundler-blue?logo=github)](https://github.com/marketplace/actions/rust-bundler)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A GitHub Action to automatically bundle Rust binaries for distribution on macOS, Windows, and Linux.

## Features

- 🪟 **Windows**: Creates `.zip` archives with icons
- 🐧 **Linux**: Creates `.tar.gz` archives with `.desktop` files
- 🍎 **macOS**: Creates `.app` bundles with proper structure and icons
- 🎨 **Metadata & Icons**: Automatically extracts metadata using `cargo metadata` and embeds icons
- 🔐 **Code Signing**: Supports macOS code signing
- 📦 **Flexible**: Include additional files and folders in your bundles
- 🎯 **Simple**: Easy integration with your existing workflows

## Quick Start

### Minimal Configuration

With auto-discovery, you can use the action with minimal configuration:

```yaml
- name: Bundle Application
  uses: julcst/rust-bundler@v1
```

The action will automatically:
- Discover `Cargo.toml` in the working directory to extract package metadata using `cargo metadata`
- Use the package name as the binary name
- Auto-discover the binary path from cargo metadata
- Look for `icon.png` in common locations (optional, works without it)
- Detect the platform and create the appropriate bundle

**Note:** Metadata and icons are always optional. The action works fine without them, creating minimal bundles containing just the binary and any included files.

### Typical Usage (Recommended)

Point to your project root and let auto-discovery do the rest:

```yaml
- name: Bundle Application
  uses: julcst/rust-bundler@v1
  with:
    working-directory: examples/my-app  # Your project root
    include-files: 'assets/ README.md LICENSE'
```

The binary will be auto-discovered in `target/release` or `target/debug`.

### With Only Binary Name

If auto-discovery doesn't work or you don't have Cargo.toml:

```yaml
- name: Bundle Application
  uses: julcst/rust-bundler@v1
  with:
    binary-name: your-app-name
```

### Explicit Configuration

You can also specify everything explicitly:

```yaml
- name: Bundle Application
  uses: julcst/rust-bundler@v1
  with:
    binary-name: your-app-name
    icon-path: 'icon.png'
    cargo-toml-path: 'Cargo.toml'
```

The action automatically detects the platform and creates the appropriate bundle in the `dist/` directory with embedded metadata and icons.

## Usage

### Complete Example with Caching

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Rust
        uses: dtolnay/rust-toolchain@stable
      
      - name: Setup sccache (optional)
        uses: mozilla-actions/sccache-action@v0.0.4
        continue-on-error: true
      
      - name: Setup Rust cache
        uses: Swatinem/rust-cache@v2
      
      - name: Configure sccache
        continue-on-error: true
        run: |
          echo "RUSTC_WRAPPER=sccache" >> $GITHUB_ENV
          echo "SCCACHE_GHA_ENABLED=true" >> $GITHUB_ENV
        shell: bash
          
      - name: Build
        run: cargo build --release
        
      - name: Bundle
        uses: julcst/rust-bundler@v1
        with:
          binary-name: myapp
          icon-path: 'icon.png'
          cargo-toml-path: 'Cargo.toml'
          
      - name: Upload Bundle
        uses: actions/upload-artifact@v4
        with:
          name: myapp-${{ matrix.os }}
          path: dist/*
```

### Cross-Platform Release Example

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            target: x86_64-unknown-linux-gnu
          - os: windows-latest
            target: x86_64-pc-windows-msvc
          - os: macos-latest
            target: x86_64-apple-darwin
    runs-on: ${{ matrix.os }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          targets: ${{ matrix.target }}
      
      - name: Setup sccache (optional)
        uses: mozilla-actions/sccache-action@v0.0.4
        continue-on-error: true
      
      - name: Setup Rust cache
        uses: Swatinem/rust-cache@v2
      
      - name: Build
        run: cargo build --release --target ${{ matrix.target }}
        env:
          RUSTC_WRAPPER: sccache
        
      - name: Bundle
        uses: julcst/rust-bundler@v1
        with:
          binary-name: myapp
          icon-path: 'icon.png'
          cargo-toml-path: 'Cargo.toml'
          include-files: 'README.md LICENSE'
          working-directory: './target/${{ matrix.target }}/release'
          
      - name: Upload to Release
        uses: softprops/action-gh-release@v2
        with:
          files: dist/*
```

### macOS Code Signing

For signed macOS releases, add certificate import before bundling:

```yaml
      - name: Import Code Signing Certificate
        if: runner.os == 'macOS'
        uses: apple-actions/import-codesign-certs@v2
        with:
          p12-file-base64: ${{ secrets.CERTIFICATES_P12 }}
          p12-password: ${{ secrets.CERTIFICATES_P12_PASSWORD }}
          
      - name: Bundle and Sign
        if: runner.os == 'macOS'
        uses: julcst/rust-bundler@v1
        with:
          binary-name: myapp
          macos-sign: true
          macos-sign-identity: "Developer ID Application: Your Name (TEAM_ID)"
          macos-bundle-id: com.example.myapp
          icon-path: 'icon.png'
          cargo-toml-path: 'Cargo.toml'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `binary-name` | Name of the binary to bundle (without extension). Auto-discovered from Cargo.toml if not provided. | No | Auto-discovered |
| `include-files` | Space-separated list of files or folders to include | No | `""` |
| `output-name` | Name of the output bundle (without extension) | No | Same as `binary-name` |
| `working-directory` | Working directory (project root). Binary auto-discovered in target/release or target/debug. | No | `.` |
| `icon-path` | Path to icon file (PNG format, will be converted per platform). Auto-discovered if not provided. | No | Auto-discovered |
| `cargo-toml-path` | Path to Cargo.toml for extracting metadata. Auto-discovered if not provided. | No | Auto-discovered |
| `macos-sign` | Enable macOS code signing | No | `false` |
| `macos-sign-identity` | macOS code signing identity | No | `""` |
| `macos-bundle-id` | macOS bundle identifier | No | `com.example.{binary-name}` |
| `macos-app-name` | macOS application display name | No | Same as `binary-name` |

## Outputs

| Output | Description |
|--------|-------------|
| `bundle-path` | Path to the created bundle |
| `bundle-name` | Name of the created bundle file |

## Output Structure

### Windows (ZIP)
```
myapp-windows.zip
├── myapp.exe                       # Binary (with embedded metadata/icon if build.rs used)
├── README.md                       # Additional files (if included)
└── LICENSE
```

### Linux (tar.gz)
```
myapp-linux.tar.gz
├── myapp
├── myapp.png                       # Icon (if icon-path provided)
├── myapp.desktop                   # Desktop entry (if cargo metadata available)
├── README.md                       # Additional files (if included)
└── LICENSE
```

### macOS (.app)
```
myapp-macos.app/
└── Contents/
    ├── Info.plist                  # With metadata from cargo metadata
    ├── MacOS/
    │   ├── myapp
    │   ├── README.md               # Additional files (if included)
    │   └── LICENSE
    └── Resources/
        └── AppIcon.icns            # Converted icon (if icon-path provided)
```

## Metadata and Icon Support

The bundler can automatically extract metadata using `cargo metadata` command and embed icons into your application bundles. **Both metadata and icons are completely optional** - the action works fine without them, creating minimal bundles.

### Auto-Discovery

The action automatically discovers common files when available:

**Cargo.toml**: Only searched in the working directory root:
- `Cargo.toml` (in working directory)

**Icon file** (optional): Searched in the following locations:
- `icon.png` (current directory)
- `./icon.png`
- `assets/icon.png`
- `resources/icon.png`
- `../icon.png`
- `../assets/icon.png`

**Binary location**: Automatically determined from `cargo metadata` output:
- Uses the `target_directory` field from cargo metadata
- Searches in `target/release` and `target/debug` subdirectories
- Falls back to manual search if cargo metadata is unavailable

**Binary name**: Automatically extracted from the binary target in `Cargo.toml` using `cargo metadata`.

If these files are not found, the action continues normally and creates a minimal bundle.

### Metadata Extraction

When `Cargo.toml` is found in the working directory, the bundler uses `cargo metadata` to extract:
- **Package Name**: Used for display name and binary name (if not provided)
- **Version**: Embedded in platform-specific metadata
- **Description**: Used in `.desktop` files (Linux) and `Info.plist` (macOS)
- **Authors**: Used in metadata where applicable
- **Target Directory**: Used to locate the compiled binary
- **Binary Name**: Extracted from binary targets

If `Cargo.toml` is not found or `cargo metadata` fails, bundles are created without metadata.

### Icon Conversion

When an icon is found (auto-discovered or explicitly provided), PNG format recommended:
- **Linux**: Copied as-is alongside the `.desktop` file
- **macOS**: Automatically converted to `.icns` format using `sips` and `iconutil` (falls back to PNG if tools unavailable)
- **Windows**: Automatically converted to `.ico` format using ImageMagick or `icotool` (falls back to PNG if tools unavailable)

If no icon is found, bundles are created without icons.

### Platform-Specific Notes

#### Windows Resource Embedding

On Windows, metadata and icons should be embedded at build time using a build script. This is the recommended approach as it embeds resources directly into the executable before bundling.

**Setup:**

1. Add `winres` to your `Cargo.toml` build dependencies:
   ```toml
   [build-dependencies]
   winres = "0.1"
   ```

2. Create a `build.rs` file in your project root:
   ```rust
   fn main() {
       if cfg!(target_os = "windows") {
           let mut res = winres::WindowsResource::new();
           res.set_icon("icon.ico");
           res.compile().unwrap();
       }
   }
   ```

3. The `winres` crate automatically reads metadata from your `Cargo.toml` (name, version, description, authors).

4. Place your icon file (`.ico` format) in the project root or convert from PNG using ImageMagick:
   ```bash
   convert icon.png -define icon:auto-resize=256,128,96,64,48,32,16 icon.ico
   ```

**Note:** With this approach, the executable will already have embedded metadata and icons when bundled.

#### Including Additional Files

To control which files are included in your source distribution (and available during builds), use the `include` field in `Cargo.toml`:

```toml
[package]
name = "myapp"
include = [
    "src/**/*",
    "Cargo.toml",
    "Cargo.lock",
    "icon.ico",
    "build.rs",
    "README.md",
    "LICENSE",
]
```

This is preferred over using the action's `include-files` parameter for files needed during the build process. The `include-files` parameter is best used for runtime assets that should be bundled with the final application.

#### Linux Desktop Files
The generated `.desktop` file follows the [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/latest/). Install it to `~/.local/share/applications/` or `/usr/share/applications/` for desktop integration.

#### macOS Icons
Icon conversion requires macOS-specific tools (`sips` and `iconutil`), which are included with macOS. When these tools are not available (e.g., on non-macOS runners), the original PNG will be included in the Resources directory as a fallback.

#### macOS Code Signing
All macOS `.app` bundles are automatically signed with an ad-hoc signature (using `codesign --sign -`) to prevent "damaged" errors on modern macOS and Apple Silicon. This allows the app to run locally without full code signing. For distribution, use the `macos-sign` option with a proper Developer ID certificate.

## Requirements

- The binary must be built before running this action (e.g., with `cargo build --release`)
- For macOS code signing, proper certificates must be imported into the keychain first
- For Windows ZIP creation on non-Windows runners, the `zip` utility must be available
- For optimal icon conversion:
  - **macOS**: `sips` and `iconutil` (included with macOS, falls back to PNG if unavailable)
  - **Windows**: ImageMagick or `icotool` (optional, falls back to PNG if unavailable)
  - **Linux**: No conversion needed (uses PNG directly)

## Troubleshooting

### Binary Not Found

If you get "Binary not found" error:
- Verify the binary name matches exactly (without .exe extension, even on Windows)
- Check that `working-directory` points to the correct location
- Ensure `cargo build --release` completed successfully

### Permission Denied on Linux/macOS

If you get permission errors when running the binary from the bundle:
- The action automatically sets executable permissions for Linux tar.gz files
- For macOS, the binary in the .app bundle is also marked as executable

### Code Signing Fails on macOS

If code signing fails:
- Ensure certificates are properly imported into the keychain
- Use the correct signing identity format: "Developer ID Application: Your Name (YOUR_TEAM_ID)"
  - Replace "Your Name" with your developer name
  - Replace "YOUR_TEAM_ID" with your Apple Team ID (10 characters)
- Check that the bundle ID is in reverse domain notation (e.g., com.example.app)
- Verify the certificate is valid and not expired

### macOS "Damaged" or "Can't be opened" Error

If macOS reports the app is damaged or can't be opened:
- The bundler automatically applies ad-hoc code signing to prevent this issue
- If you still see this error after downloading, run: `xattr -cr path/to/app.app` to remove quarantine attributes
- For distribution to other users, use proper code signing with `macos-sign: true` and a Developer ID certificate

### Files Not Included

If additional files are missing from the bundle:
- File paths in `include-files` should be relative to the repository root
- Use space-separated list: `"file1.txt file2.txt folder/"`
- Check that the files exist before the bundling step runs

## Publishing to GitHub Marketplace

This action is ready to be published to the GitHub Marketplace:

1. Create a release with a tag (e.g., `v1.0.0`)
2. The action will automatically appear in the GitHub Marketplace
3. Users can reference it with: `julcst/rust-bundler@v1`

### Version Tags

We follow semantic versioning:
- Major versions: `v1`, `v2` (breaking changes)
- Minor versions: `v1.1`, `v1.2` (new features, backward compatible)
- Patch versions: `v1.0.1`, `v1.0.2` (bug fixes)

Users can pin to specific versions or use major version tags that always point to the latest compatible version.

## Examples

The repository includes a working example in the `examples/` directory:

### Hello World Example

A simple Rust application that demonstrates bundling assets with your application. The example reads and displays text from a bundled `assets/hello.txt` file, showing how to include additional files and folders in your bundles.

See [examples/hello-world/README.md](examples/hello-world/README.md) for details.

This example is automatically tested on Linux, Windows, and macOS via CI to ensure the bundler works correctly across all platforms.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to contribute to this project.

## License

MIT
