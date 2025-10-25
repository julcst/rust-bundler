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
      
      - name: Setup sccache
        uses: mozilla-actions/sccache-action@v0.0.4
      
      - name: Setup Rust cache
        uses: Swatinem/rust-cache@v2
      
      - name: Configure sccache
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
      
      - name: Setup sccache
        uses: mozilla-actions/sccache-action@v0.0.4
      
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
