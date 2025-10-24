# Rust Bundler

A GitHub Action to automatically bundle Rust binaries for distribution on macOS, Windows, and Linux.

## Features

- 🪟 **Windows**: Creates `.zip` archives
- 🐧 **Linux**: Creates `.tar.gz` archives  
- 🍎 **macOS**: Creates `.app` bundles with proper structure
- 🔐 **Code Signing**: Supports macOS code signing
- 📦 **Flexible**: Include additional files and folders in your bundles
- 🎯 **Simple**: Easy integration with your existing workflows

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
          macos-sign-identity: "Developer ID Application: Your Name (TEAM_ID)"
          macos-bundle-id: com.example.myapp
          macos-app-name: "My Application"
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
├── README.md
└── LICENSE
```

### Linux (tar.gz)
```
myapp-linux.tar.gz
├── myapp
├── README.md
└── LICENSE
```

### macOS (.app)
```
myapp-macos.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/
    │   ├── myapp
    │   ├── README.md
    │   └── LICENSE
    └── Resources/
```

## Requirements

- The binary must be built before running this action (e.g., with `cargo build --release`)
- For macOS code signing, proper certificates must be imported into the keychain first
- For Windows ZIP creation on non-Windows runners, the `zip` utility must be available

## Platform-Specific Notes

### macOS
- Creates a standard macOS application bundle with `Info.plist`
- Additional files are placed in `Contents/MacOS/`
- Code signing requires:
  - Valid Apple Developer certificate imported into keychain
  - Signing identity (e.g., "Developer ID Application: Name (TEAM_ID)")
  - Bundle identifier (reverse domain notation)

### Windows
- Creates ZIP archives compatible with Windows
- Binary is named with `.exe` extension automatically
- Uses PowerShell's `Compress-Archive` or `zip` utility

### Linux
- Creates compressed tar archives
- Binary maintains executable permissions
- Compatible with all major Linux distributions

## License

MIT
