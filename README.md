# Rust Bundler

[![GitHub release](https://img.shields.io/github/v/release/julcst/rust-bundler)](https://github.com/julcst/rust-bundler/releases)
[![GitHub marketplace](https://img.shields.io/badge/marketplace-rust--bundler-blue?logo=github)](https://github.com/marketplace/actions/rust-bundler)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A GitHub Action to automatically bundle Rust binaries for distribution on macOS, Windows, and Linux.

## Features

- 🪟 **Windows**: Creates `.zip` archives with icon and resource files
- 🐧 **Linux**: Creates `.tar.gz` archives with `.desktop` files
- 🍎 **macOS**: Creates `.app` bundles with proper structure and icons
- 🎨 **Metadata & Icons**: Automatically extracts metadata from `Cargo.toml` and embeds icons
- 🔐 **Code Signing**: Supports macOS code signing
- 📦 **Flexible**: Include additional files and folders in your bundles
- 🎯 **Simple**: Easy integration with your existing workflows

## Quick Start

Add this to your GitHub Actions workflow after building your Rust project:

```yaml
- name: Bundle Application
  uses: julcst/rust-bundler@v1
  with:
    binary-name: your-app-name
```

That's it! The action will automatically detect the platform and create the appropriate bundle in the `dist/` directory.

## Usage

### Basic Example

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
      
      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          
      - name: Build
        run: cargo build --release
        
      - name: Bundle
        uses: julcst/rust-bundler@v1
        with:
          binary-name: myapp
          
      - name: Upload Bundle
        uses: actions/upload-artifact@v4
        with:
          name: myapp-${{ matrix.os }}
          path: dist/*
```

### Advanced Example with Additional Files

```yaml
      - name: Bundle with Additional Files
        uses: julcst/rust-bundler@v1
        with:
          binary-name: myapp
          output-name: MyApplication
          include-files: 'README.md LICENSE config.json assets/'
          working-directory: './target/release'
```

### Example with Metadata and Icon

```yaml
      - name: Bundle with Metadata and Icon
        uses: julcst/rust-bundler@v1
        with:
          binary-name: myapp
          output-name: MyApplication
          icon-path: 'icon.png'
          cargo-toml-path: 'Cargo.toml'
          include-files: 'README.md LICENSE'
```

This will:
- **Linux**: Include a `.desktop` file with metadata and `icon.png`
- **macOS**: Convert `icon.png` to `.icns` format and update `Info.plist` with version and description
- **Windows**: Convert `icon.png` to `.ico` format and generate resource files (`.rc`) for build-time embedding

### macOS Code Signing Example

```yaml
      - name: Import Code Signing Certificate
        if: matrix.os == 'macos-latest'
        uses: apple-actions/import-codesign-certs@v2
        with:
          p12-file-base64: ${{ secrets.CERTIFICATES_P12 }}
          p12-password: ${{ secrets.CERTIFICATES_P12_PASSWORD }}
          
      - name: Bundle and Sign for macOS
        if: matrix.os == 'macos-latest'
        uses: julcst/rust-bundler@v1
        with:
          binary-name: myapp
          output-name: MyApplication
          macos-sign: true
          macos-sign-identity: "Developer ID Application: Your Name (YOUR_TEAM_ID)"
          macos-bundle-id: com.example.myapp
          macos-app-name: "My Application"
          icon-path: 'icon.png'
          cargo-toml-path: 'Cargo.toml'
          include-files: 'README.md LICENSE'
```

### Publishing to GitHub Releases

```yaml
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: dist/*
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `binary-name` | Name of the binary to bundle (without extension) | Yes | - |
| `include-files` | Space-separated list of files or folders to include | No | `""` |
| `output-name` | Name of the output bundle (without extension) | No | Same as `binary-name` |
| `working-directory` | Directory containing the binary | No | `./target/release` |
| `icon-path` | Path to icon file (PNG format, will be converted per platform) | No | `""` |
| `cargo-toml-path` | Path to Cargo.toml for extracting metadata | No | `""` |
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
├── myapp.exe
├── myapp.ico                      # Converted icon (if icon-path provided)
├── myapp.rc                       # Resource file template (if cargo-toml-path provided)
├── WINDOWS_RESOURCES_README.txt   # Instructions for embedding resources
├── README.md
└── LICENSE
```

### Linux (tar.gz)
```
myapp-linux.tar.gz
├── myapp
├── myapp.png                      # Icon (if icon-path provided)
├── myapp.desktop                  # Desktop entry (if cargo-toml-path provided)
├── README.md
└── LICENSE
```

### macOS (.app)
```
myapp-macos.app/
└── Contents/
    ├── Info.plist                 # With metadata from Cargo.toml
    ├── MacOS/
    │   ├── myapp
    │   ├── README.md
    │   └── LICENSE
    └── Resources/
        └── AppIcon.icns           # Converted icon (if icon-path provided)
```

## Metadata and Icon Support

The bundler can automatically extract metadata from your `Cargo.toml` and embed icons into your application bundles.

### Metadata Extraction

When you provide `cargo-toml-path`, the bundler extracts:
- **Package Name**: Used for display name
- **Version**: Embedded in platform-specific metadata
- **Description**: Used in `.desktop` files (Linux), `Info.plist` (macOS), and resource files (Windows)
- **Authors**: Used in Windows resource files

### Icon Conversion

When you provide `icon-path` (PNG format recommended):
- **Linux**: Copied as-is alongside the `.desktop` file
- **macOS**: Automatically converted to `.icns` format using `sips` and `iconutil` (falls back to PNG if tools unavailable)
- **Windows**: Automatically converted to `.ico` format using ImageMagick or `icotool` (falls back to PNG if tools unavailable)

### Platform-Specific Notes

#### Windows Resource Embedding
Windows resource files (`.rc`) are included in the bundle for reference. To embed icons and metadata at build time:

1. Add `winres` to your `Cargo.toml`:
   ```toml
   [build-dependencies]
   winres = "0.1"
   ```

2. Create a `build.rs` file:
   ```rust
   fn main() {
       if cfg!(target_os = "windows") {
           let mut res = winres::WindowsResource::new();
           res.set_icon("icon.ico");
           res.compile().unwrap();
       }
   }
   ```

The `winres` crate will automatically read metadata from your `Cargo.toml`.

#### Linux Desktop Files
The generated `.desktop` file follows the [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/latest/). Install it to `~/.local/share/applications/` or `/usr/share/applications/` for desktop integration.

#### macOS Icons
Icon conversion requires macOS-specific tools (`sips` and `iconutil`), which are included with macOS. When these tools are not available (e.g., on non-macOS runners), the original PNG will be included in the Resources directory as a fallback.

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

### Files Not Included

If additional files are missing from the bundle:
- File paths in `include-files` should be relative to the repository root
- Use space-separated list: `"file1.txt file2.txt folder/"`
- Check that the files exist before the bundling step runs

## Platform-Specific Notes

### macOS
- Creates a standard macOS application bundle with `Info.plist`
- Additional files are placed in `Contents/MacOS/`
- Code signing requires:
  - Valid Apple Developer certificate imported into keychain
  - Signing identity (e.g., "Developer ID Application: Name (YOUR_TEAM_ID)")
  - Bundle identifier (reverse domain notation)

### Windows
- Creates ZIP archives compatible with Windows
- Binary is named with `.exe` extension automatically
- Uses PowerShell's `Compress-Archive` or `zip` utility

### Linux
- Creates compressed tar archives
- Binary maintains executable permissions
- Compatible with all major Linux distributions

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

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes in each version.

## License

MIT
