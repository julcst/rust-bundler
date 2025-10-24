# Contributing to Rust Bundler

Thank you for your interest in contributing to Rust Bundler!

## Development

### Testing Locally

You can test the action using the included hello-world example:

```bash
# Build the example
cd examples/hello-world
cargo build --release
cd ../..

# Test bundling
source scripts/bundle.sh
bundle_application \
  "hello-world" \
  "examples/hello-world/assets/" \
  "" \
  "./examples/hello-world/target/release" \
  "false" \
  "" \
  "" \
  ""

# Extract and test the bundle
mkdir -p test-extract
tar -xzf dist/hello-world-linux.tar.gz -C test-extract
cd test-extract
./hello-world
```

To test with your own binary, use the bundling script directly:

```bash
# Source the script
source scripts/bundle.sh

# Call the bundling function
bundle_application \
  "your-binary-name" \
  "file1.txt file2.txt folder/" \
  "output-name" \
  "./target/release" \
  "false" \
  "" \
  "" \
  ""
```

### Testing in a Workflow

The repository includes a test workflow that automatically runs on every pull request. This workflow tests the hello-world example on Linux, Windows, and macOS to ensure the bundler works correctly across all platforms.

You can also test in a GitHub Actions workflow by creating a test repository with a Rust project and reference this action:

```yaml
- name: Bundle
  uses: your-username/rust-bundler@branch-name
  with:
    binary-name: myapp
```

## Code Style

- Use clear, descriptive variable names
- Add comments for complex logic
- Follow existing shell script conventions
- Test on Linux, macOS, and Windows when possible

## Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Reporting Issues

When reporting issues, please include:

- Operating system and version
- GitHub Actions runner type (ubuntu-latest, etc.)
- Full workflow YAML
- Complete error messages
- Steps to reproduce

## Feature Requests

Feature requests are welcome! Please describe:

- The use case
- Expected behavior
- How it would benefit users
