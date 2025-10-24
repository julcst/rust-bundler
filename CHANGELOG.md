# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of Rust Bundler GitHub Action
- Windows ZIP bundling support
- Linux tar.gz bundling support
- macOS .app bundle creation
- macOS code signing support
- Configurable binary name and output name
- Support for including additional files and folders
- Comprehensive documentation and examples
- Example workflows for basic usage, releases, and macOS signing

### Features
- Cross-platform support (Linux, macOS, Windows)
- Automatic platform detection
- Flexible file inclusion
- Proper .app bundle structure for macOS
- Code signing with verification for macOS
- Executable permissions preserved in tar.gz
- GitHub Actions outputs for bundle path and name

[Unreleased]: https://github.com/julcst/rust-bundler/compare/v1.0.0...HEAD
