#!/bin/bash

set -e

bundle_application() {
    local binary_name="$1"
    local include_files="$2"
    local output_name="$3"
    local working_directory="$4"
    local macos_sign="$5"
    local macos_sign_identity="$6"
    local macos_bundle_id="$7"
    local macos_app_name="$8"
    
    # Determine output name
    if [ -z "$output_name" ]; then
        output_name="$binary_name"
    fi
    
    # Detect OS
    OS=$(uname -s)
    
    echo "🎯 Bundling $binary_name for $OS"
    echo "📂 Working directory: $working_directory"
    
    # Check if binary exists
    local binary_path=""
    if [ "$OS" = "Darwin" ] || [ "$OS" = "Linux" ]; then
        binary_path="$working_directory/$binary_name"
    elif [ "$OS" = "MINGW64_NT" ] || [ "$OS" = "MSYS_NT" ] || [[ "$OS" == MINGW* ]] || [[ "$OS" == MSYS* ]] || [[ "$OS" == CYGWIN* ]]; then
        OS="Windows"
        binary_path="$working_directory/${binary_name}.exe"
    else
        echo "❌ Unsupported OS: $OS"
        exit 1
    fi
    
    if [ ! -f "$binary_path" ]; then
        echo "❌ Binary not found at: $binary_path"
        exit 1
    fi
    
    echo "✅ Binary found at: $binary_path"
    
    # Create output directory
    mkdir -p dist
    
    # Bundle based on OS
    case "$OS" in
        Linux)
            bundle_linux "$binary_name" "$binary_path" "$include_files" "$output_name"
            ;;
        Darwin)
            if [ "$macos_sign" = "true" ]; then
                bundle_macos_with_signing "$binary_name" "$binary_path" "$include_files" "$output_name" "$macos_sign_identity" "$macos_bundle_id" "$macos_app_name"
            else
                bundle_macos "$binary_name" "$binary_path" "$include_files" "$output_name" "$macos_bundle_id" "$macos_app_name"
            fi
            ;;
        Windows)
            bundle_windows "$binary_name" "$binary_path" "$include_files" "$output_name"
            ;;
        *)
            echo "❌ Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

bundle_linux() {
    local binary_name="$1"
    local binary_path="$2"
    local include_files="$3"
    local output_name="$4"
    
    local bundle_name="${output_name}-linux.tar.gz"
    local temp_dir=$(mktemp -d)
    
    echo "📦 Creating Linux tar.gz bundle: $bundle_name"
    
    # Copy binary
    cp "$binary_path" "$temp_dir/$binary_name"
    chmod +x "$temp_dir/$binary_name"
    
    # Copy additional files
    if [ -n "$include_files" ]; then
        for file in $include_files; do
            if [ -e "$file" ]; then
                echo "  📄 Including: $file"
                cp -r "$file" "$temp_dir/"
            else
                echo "  ⚠️  File not found: $file"
            fi
        done
    fi
    
    # Create tar.gz
    tar -czf "dist/$bundle_name" -C "$temp_dir" .
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "✅ Bundle created: dist/$bundle_name"
    echo "bundle-path=dist/$bundle_name" >> $GITHUB_OUTPUT
    echo "bundle-name=$bundle_name" >> $GITHUB_OUTPUT
}

bundle_windows() {
    local binary_name="$1"
    local binary_path="$2"
    local include_files="$3"
    local output_name="$4"
    
    local bundle_name="${output_name}-windows.zip"
    local temp_dir=$(mktemp -d)
    
    echo "📦 Creating Windows zip bundle: $bundle_name"
    
    # Copy binary
    cp "$binary_path" "$temp_dir/${binary_name}.exe"
    
    # Copy additional files
    if [ -n "$include_files" ]; then
        for file in $include_files; do
            if [ -e "$file" ]; then
                echo "  📄 Including: $file"
                cp -r "$file" "$temp_dir/"
            else
                echo "  ⚠️  File not found: $file"
            fi
        done
    fi
    
    # Create zip (using PowerShell on Windows or zip command on Unix)
    if command -v zip &> /dev/null; then
        (cd "$temp_dir" && zip -r "../../dist/$bundle_name" .)
    elif command -v pwsh &> /dev/null; then
        pwsh -Command "Compress-Archive -Path '$temp_dir/*' -DestinationPath 'dist/$bundle_name' -Force"
    elif command -v powershell &> /dev/null; then
        powershell -Command "Compress-Archive -Path '$temp_dir/*' -DestinationPath 'dist/$bundle_name' -Force"
    else
        echo "❌ No zip utility found"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "✅ Bundle created: dist/$bundle_name"
    echo "bundle-path=dist/$bundle_name" >> $GITHUB_OUTPUT
    echo "bundle-name=$bundle_name" >> $GITHUB_OUTPUT
}

bundle_macos() {
    local binary_name="$1"
    local binary_path="$2"
    local include_files="$3"
    local output_name="$4"
    local bundle_id="$5"
    local app_name="$6"
    
    # Set defaults
    if [ -z "$app_name" ]; then
        app_name="$binary_name"
    fi
    
    if [ -z "$bundle_id" ]; then
        bundle_id="com.example.${binary_name}"
    fi
    
    local bundle_name="${output_name}-macos.app"
    local app_dir="dist/$bundle_name"
    
    echo "📦 Creating macOS .app bundle: $bundle_name"
    
    # Create app bundle structure
    mkdir -p "$app_dir/Contents/MacOS"
    mkdir -p "$app_dir/Contents/Resources"
    
    # Copy binary
    cp "$binary_path" "$app_dir/Contents/MacOS/$binary_name"
    chmod +x "$app_dir/Contents/MacOS/$binary_name"
    
    # Copy additional files to MacOS directory
    if [ -n "$include_files" ]; then
        for file in $include_files; do
            if [ -e "$file" ]; then
                echo "  📄 Including: $file"
                cp -r "$file" "$app_dir/Contents/MacOS/"
            else
                echo "  ⚠️  File not found: $file"
            fi
        done
    fi
    
    # Create Info.plist
    cat > "$app_dir/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$binary_name</string>
    <key>CFBundleIdentifier</key>
    <string>$bundle_id</string>
    <key>CFBundleName</key>
    <string>$app_name</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
    
    echo "✅ Bundle created: $app_dir"
    echo "bundle-path=$app_dir" >> $GITHUB_OUTPUT
    echo "bundle-name=$bundle_name" >> $GITHUB_OUTPUT
}

bundle_macos_with_signing() {
    local binary_name="$1"
    local binary_path="$2"
    local include_files="$3"
    local output_name="$4"
    local sign_identity="$5"
    local bundle_id="$6"
    local app_name="$7"
    
    # First create the unsigned bundle
    bundle_macos "$binary_name" "$binary_path" "$include_files" "$output_name" "$bundle_id" "$app_name"
    
    local bundle_name="${output_name}-macos.app"
    local app_dir="dist/$bundle_name"
    
    echo "🔐 Signing macOS application..."
    
    if [ -z "$sign_identity" ]; then
        echo "❌ macOS signing identity is required for signing"
        exit 1
    fi
    
    # Sign the application
    codesign --force --deep --sign "$sign_identity" "$app_dir"
    
    # Verify the signature
    if codesign --verify --verbose "$app_dir"; then
        echo "✅ Application signed successfully"
    else
        echo "❌ Application signing verification failed"
        exit 1
    fi
    
    # Display signature information
    codesign --display --verbose=4 "$app_dir" 2>&1 || true
}
