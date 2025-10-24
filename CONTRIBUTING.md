# Contributing to Rust Bundler

Thank you for your interest in contributing to Rust Bundler!

## Development

### Testing Locally

To test the action locally, you can use the bundling script directly:

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

To test in a GitHub Actions workflow, create a test repository with a Rust project and reference this action:

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
