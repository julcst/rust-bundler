#!/bin/bash

set -e

# Function to convert profile name to directory name
# Handles historical naming: dev/test -> debug, release/bench -> release
profile_to_dir() {
    local profile="$1"
    
    case "$profile" in
        dev|test)
            echo "debug"
            ;;
        release|bench)
            echo "release"
            ;;
        *)
            # Custom profiles use their own name
            echo "$profile"
            ;;
    esac
}

# Function to auto-discover binary location
auto_discover_binary() {
    local binary_name="$1"
    local working_dir="$2"
    
    if [ -z "$binary_name" ]; then
        return 1
    fi
    
    # Normalize working_dir
    if [ -z "$working_dir" ]; then
        working_dir="."
    fi
    
    # Search paths for the binary (relative to working_dir)
    local search_paths=(
        "target/release/$binary_name"
        "target/debug/$binary_name"
        "target/release/${binary_name}.exe"
        "target/debug/${binary_name}.exe"
        "$binary_name"
        "${binary_name}.exe"
    )
    
    # Search for binary in working_dir
    for path in "${search_paths[@]}"; do
        local full_path="$working_dir/$path"
        if [ -f "$full_path" ]; then
            # Return the directory containing the binary
            dirname "$full_path"
            return 0
        fi
    done
    
    return 1
}

# Function to auto-discover icon file
auto_discover_icon() {
    local search_paths=(
        "icon.png"
        "./icon.png"
        "assets/icon.png"
        "resources/icon.png"
        "../icon.png"
        "../assets/icon.png"
    )
    
    for path in "${search_paths[@]}"; do
        if [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Function to extract metadata using cargo metadata command
extract_cargo_metadata() {
    local working_dir="$1"
    
    # Check if cargo is available
    if ! command -v cargo &> /dev/null; then
        echo "⚠️  cargo command not found, cannot extract metadata"
        return 1
    fi
    
    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        echo "⚠️  jq command not found, cannot parse cargo metadata"
        return 1
    fi
    
    # Run cargo metadata and extract package information
    # cargo metadata will fail if there's no Cargo.toml, so we don't need to check explicitly
    local metadata
    if ! metadata=$(cd "$working_dir" && cargo metadata --no-deps --format-version 1 2>/dev/null); then
        return 1
    fi
    
    # Extract first package from the workspace
    local package
    package=$(echo "$metadata" | jq -r '.packages[0]')
    
    if [ "$package" = "null" ] || [ -z "$package" ]; then
        return 1
    fi
    
    # Extract metadata fields
    CARGO_PKG_NAME=$(echo "$package" | jq -r '.name')
    CARGO_PKG_VERSION=$(echo "$package" | jq -r '.version')
    CARGO_PKG_DESCRIPTION=$(echo "$package" | jq -r '.description // ""')
    CARGO_PKG_AUTHORS=$(echo "$package" | jq -r '.authors[0] // ""')
    CARGO_TARGET_DIR=$(echo "$metadata" | jq -r '.target_directory')
    CARGO_PKG_README=$(echo "$package" | jq -r '.readme // ""')
    CARGO_PKG_LICENSE_FILE=$(echo "$package" | jq -r '.license_file // ""')
    
    # Extract include field from manifest
    local manifest_path
    manifest_path=$(echo "$package" | jq -r '.manifest_path')
    if [ -f "$manifest_path" ]; then
        # Extract include field array from Cargo.toml using cargo metadata
        CARGO_PKG_INCLUDE=$(echo "$package" | jq -r '.include // [] | join(" ")')
    fi
    
    # Extract binary target information
    # Prefer binary target with same name as package, otherwise use first binary target
    local bin_targets
    bin_targets=$(echo "$package" | jq -r '.targets[] | select(.kind[] == "bin") | .name')
    if [ -n "$bin_targets" ]; then
        # Try to find binary matching package name
        local bin_target
        bin_target=$(echo "$bin_targets" | grep -x "$CARGO_PKG_NAME" | head -1)
        if [ -z "$bin_target" ]; then
            # Fallback to first binary target if no match with package name
            bin_target=$(echo "$bin_targets" | head -1)
        fi
        if [ -n "$bin_target" ]; then
            CARGO_BIN_NAME="$bin_target"
        fi
    fi
    
    export CARGO_PKG_NAME CARGO_PKG_VERSION CARGO_PKG_DESCRIPTION CARGO_PKG_AUTHORS CARGO_TARGET_DIR CARGO_BIN_NAME CARGO_PKG_README CARGO_PKG_LICENSE_FILE CARGO_PKG_INCLUDE
}

# Function to convert PNG to ICNS (macOS icon format)
convert_png_to_icns() {
    local png_path="$1"
    local icns_path="$2"
    
    if [ ! -f "$png_path" ]; then
        return 1
    fi
    
    # Check if sips is available (macOS)
    if command -v sips &> /dev/null; then
        local iconset_dir
        iconset_dir=$(mktemp -d)
        local iconset="${iconset_dir}/icon.iconset"
        mkdir -p "$iconset"
        
        # Generate various icon sizes required for ICNS
        sips -z 16 16 "$png_path" --out "${iconset}/icon_16x16.png" &> /dev/null
        sips -z 32 32 "$png_path" --out "${iconset}/icon_16x16@2x.png" &> /dev/null
        sips -z 32 32 "$png_path" --out "${iconset}/icon_32x32.png" &> /dev/null
        sips -z 64 64 "$png_path" --out "${iconset}/icon_32x32@2x.png" &> /dev/null
        sips -z 128 128 "$png_path" --out "${iconset}/icon_128x128.png" &> /dev/null
        sips -z 256 256 "$png_path" --out "${iconset}/icon_128x128@2x.png" &> /dev/null
        sips -z 256 256 "$png_path" --out "${iconset}/icon_256x256.png" &> /dev/null
        sips -z 512 512 "$png_path" --out "${iconset}/icon_256x256@2x.png" &> /dev/null
        sips -z 512 512 "$png_path" --out "${iconset}/icon_512x512.png" &> /dev/null
        sips -z 1024 1024 "$png_path" --out "${iconset}/icon_512x512@2x.png" &> /dev/null
        
        iconutil -c icns "$iconset" -o "$icns_path"
        rm -rf "$iconset_dir"
        return 0
    fi
    
    return 1
}

# Function to get all files to include in the bundle
get_files_to_include() {
    local working_directory="$1"
    local include_files_param="$2"
    local all_files=""
    
    # Add files from cargo metadata include field
    if [ -n "$CARGO_PKG_INCLUDE" ]; then
        all_files="$CARGO_PKG_INCLUDE"
    fi
    
    # Add README from cargo metadata
    if [ -n "$CARGO_PKG_README" ] && [ "$CARGO_PKG_README" != "false" ]; then
        if [ -f "$working_directory/$CARGO_PKG_README" ]; then
            all_files="$all_files $CARGO_PKG_README"
        fi
    fi
    
    # Add LICENSE from cargo metadata
    if [ -n "$CARGO_PKG_LICENSE_FILE" ] && [ "$CARGO_PKG_LICENSE_FILE" != "false" ]; then
        if [ -f "$working_directory/$CARGO_PKG_LICENSE_FILE" ]; then
            all_files="$all_files $CARGO_PKG_LICENSE_FILE"
        fi
    fi
    
    # Add files from include-files parameter (if not already in the list)
    if [ -n "$include_files_param" ]; then
        all_files="$all_files $include_files_param"
    fi
    
    # Remove duplicates and return
    echo "$all_files" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

bundle_application() {
    local binary_name="$1"
    local include_files="$2"
    local output_name="$3"
    local working_directory="$4"
    local macos_sign="$5"
    local macos_sign_identity="$6"
    local macos_bundle_id="$7"
    local macos_app_name="$8"
    local icon_path="$9"
    local cargo_toml_path="${10}"
    local profile="${11}"
    local target="${12}"
    
    # Default working directory to current directory if not specified
    if [ -z "$working_directory" ]; then
        working_directory="."
    fi
    
    # Default profile to release if not specified
    if [ -z "$profile" ]; then
        profile="release"
    fi
    
    # Extract metadata using cargo metadata
    echo "📋 Extracting metadata using cargo metadata from: $working_directory"
    if extract_cargo_metadata "$working_directory"; then
        echo "  Package: $CARGO_PKG_NAME"
        echo "  Version: $CARGO_PKG_VERSION"
        [ -n "$CARGO_PKG_DESCRIPTION" ] && echo "  Description: $CARGO_PKG_DESCRIPTION"
        [ -n "$CARGO_PKG_AUTHORS" ] && echo "  Author: $CARGO_PKG_AUTHORS"
        [ -n "$CARGO_TARGET_DIR" ] && echo "  Target directory: $CARGO_TARGET_DIR"
        
        # Auto-discover binary name from cargo metadata if not provided
        if [ -z "$binary_name" ]; then
            if [ -n "$CARGO_BIN_NAME" ]; then
                binary_name="$CARGO_BIN_NAME"
                echo "🔍 Auto-discovered binary name from cargo metadata: $binary_name"
            elif [ -n "$CARGO_PKG_NAME" ]; then
                binary_name="$CARGO_PKG_NAME"
                echo "🔍 Using package name as binary name: $binary_name"
            fi
        fi
    else
        echo "⚠️  Failed to extract metadata with cargo metadata, continuing without metadata"
    fi
    
    # Check if binary name is still empty
    if [ -z "$binary_name" ]; then
        echo "❌ Error: binary-name is required and could not be auto-discovered"
        echo "   Please provide binary-name input or ensure Cargo.toml is available"
        exit 1
    fi
    
    # Auto-discover icon if not provided
    if [ -z "$icon_path" ]; then
        if discovered_icon=$(cd "$working_directory" && auto_discover_icon); then
            icon_path="$working_directory/$discovered_icon"
            echo "🎨 Auto-discovered icon: $icon_path"
        fi
    fi
    
    # Determine output name
    if [ -z "$output_name" ]; then
        output_name="$binary_name"
    fi
    
    # Detect OS
    OS=$(uname -s)
    
    echo "🎯 Bundling $binary_name for $OS"
    echo "📂 Working directory: $working_directory"
    echo "📦 Profile: $profile"
    if [ -n "$target" ]; then
        echo "🎯 Target triple: $target"
    fi
    
    # Convert profile name to directory name (handles historical naming)
    local profile_dir
    profile_dir=$(profile_to_dir "$profile")
    
    # Auto-discover binary location
    local binary_path=""
    local binary_dir=""
    
    # Build the search path based on cargo metadata
    if [ -n "$CARGO_TARGET_DIR" ]; then
        echo "🔍 Using target directory from cargo metadata: $CARGO_TARGET_DIR"
        
        # Construct the binary path based on whether target triple is specified
        if [ -n "$target" ]; then
            # When target is specified: target/<triple>/<profile-dir>/
            binary_dir="$CARGO_TARGET_DIR/$target/$profile_dir"
        else
            # When no target specified: target/<profile-dir>/
            binary_dir="$CARGO_TARGET_DIR/$profile_dir"
        fi
        
        echo "🔍 Looking for binary in: $binary_dir"
    else
        # Fallback to working directory if no cargo metadata
        echo "⚠️  No cargo metadata target directory, falling back to working directory"
        binary_dir="$working_directory"
    fi
    
    # Verify the binary exists, fall back to auto-discovery if needed
    local binary_exists=false
    if [ "$OS" = "Darwin" ] || [ "$OS" = "Linux" ]; then
        if [ -f "$binary_dir/$binary_name" ]; then
            binary_exists=true
        fi
    elif [ "$OS" = "MINGW64_NT" ] || [ "$OS" = "MSYS_NT" ] || [[ "$OS" == MINGW* ]] || [[ "$OS" == MSYS* ]] || [[ "$OS" == CYGWIN* ]]; then
        if [ -f "$binary_dir/${binary_name}.exe" ]; then
            binary_exists=true
        fi
    fi
    
    # Fallback to auto-discovery if binary not found in expected location
    if [ "$binary_exists" = false ]; then
        echo "⚠️  Binary not found at expected location: $binary_dir"
        if discovered_dir=$(auto_discover_binary "$binary_name" "$working_directory"); then
            binary_dir="$discovered_dir"
            echo "🔍 Auto-discovered binary in: $binary_dir"
        fi
    fi
    
    # Check if binary exists
    if [ "$OS" = "Darwin" ] || [ "$OS" = "Linux" ]; then
        binary_path="$binary_dir/$binary_name"
    elif [ "$OS" = "MINGW64_NT" ] || [ "$OS" = "MSYS_NT" ] || [[ "$OS" == MINGW* ]] || [[ "$OS" == MSYS* ]] || [[ "$OS" == CYGWIN* ]]; then
        OS="Windows"
        binary_path="$binary_dir/${binary_name}.exe"
    else
        echo "❌ Unsupported OS: $OS"
        exit 1
    fi
    
    if [ ! -f "$binary_path" ]; then
        echo "❌ Binary not found at: $binary_path"
        echo "   Expected location: $binary_dir"
        echo "   Make sure to build your binary before bundling (e.g., cargo build --release)"
        exit 1
    fi
    
    echo "✅ Binary found at: $binary_path"
    
    # Get all files to include (from cargo metadata and include-files parameter)
    local all_include_files
    all_include_files=$(get_files_to_include "$working_directory" "$include_files")
    
    # Create output directory
    mkdir -p dist
    
    # Bundle based on OS
    case "$OS" in
        Linux)
            bundle_linux "$binary_name" "$binary_path" "$all_include_files" "$output_name" "$icon_path" "$cargo_toml_path" "$working_directory"
            ;;
        Darwin)
            if [ "$macos_sign" = "true" ]; then
                bundle_macos_with_signing "$binary_name" "$binary_path" "$all_include_files" "$output_name" "$macos_sign_identity" "$macos_bundle_id" "$macos_app_name" "$icon_path" "$cargo_toml_path" "$working_directory"
            else
                bundle_macos "$binary_name" "$binary_path" "$all_include_files" "$output_name" "$macos_bundle_id" "$macos_app_name" "$icon_path" "$cargo_toml_path" "$working_directory"
            fi
            ;;
        Windows)
            bundle_windows "$binary_name" "$binary_path" "$all_include_files" "$output_name" "$icon_path" "$cargo_toml_path" "$working_directory"
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
    local icon_path="$5"
    local cargo_toml_path="$6"
    local working_directory="$7"
    
    local bundle_name="${output_name}-linux.tar.gz"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    echo "📦 Creating Linux tar.gz bundle: $bundle_name"
    
    # Copy binary
    cp "$binary_path" "$temp_dir/$binary_name"
    chmod +x "$temp_dir/$binary_name"
    
    # Copy icon if provided
    if [ -n "$icon_path" ] && [ -f "$icon_path" ]; then
        echo "  🎨 Including icon: $icon_path"
        cp "$icon_path" "$temp_dir/${binary_name}.png"
    fi
    
    # Generate .desktop file if we have metadata from cargo
    if [ -n "$CARGO_PKG_NAME" ]; then
        echo "  📄 Generating .desktop file"
        local app_name="${CARGO_PKG_NAME:-$binary_name}"
        local version="${CARGO_PKG_VERSION:-1.0.0}"
        local description="${CARGO_PKG_DESCRIPTION:-$app_name}"
        local icon_name="${binary_name}.png"
        
        cat > "$temp_dir/${binary_name}.desktop" <<EOF
[Desktop Entry]
Name=$app_name
Version=$version
Comment=$description
Exec=$binary_name
Icon=$icon_name
Terminal=false
Type=Application
Categories=Utility;
EOF
    fi
    
    # Copy additional files (relative to working_directory)
    if [ -n "$include_files" ]; then
        for file in $include_files; do
            # Remove trailing slash to ensure consistent cp behavior
            file="${file%/}"
            local file_path="$working_directory/$file"
            if [ -e "$file_path" ]; then
                echo "  📄 Including: $file"
                cp -r "$file_path" "$temp_dir/"
            else
                echo "  ⚠️  File not found: $file_path"
            fi
        done
    fi
    
    # Create tar.gz
    tar -czf "dist/$bundle_name" -C "$temp_dir" .
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "✅ Bundle created: dist/$bundle_name"
    echo "bundle-path=dist/$bundle_name" >> "$GITHUB_OUTPUT"
    echo "bundle-name=$bundle_name" >> "$GITHUB_OUTPUT"
}

bundle_windows() {
    local binary_name="$1"
    local binary_path="$2"
    local include_files="$3"
    local output_name="$4"
    local icon_path="$5"
    local cargo_toml_path="$6"
    local working_directory="$7"
    
    local bundle_name="${output_name}-windows.zip"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    echo "📦 Creating Windows zip bundle: $bundle_name"
    
    # Copy binary
    cp "$binary_path" "$temp_dir/${binary_name}.exe"
    
    # Copy additional files (relative to working_directory)
    if [ -n "$include_files" ]; then
        for file in $include_files; do
            # Remove trailing slash to ensure consistent cp behavior
            file="${file%/}"
            local file_path="$working_directory/$file"
            if [ -e "$file_path" ]; then
                echo "  📄 Including: $file"
                cp -r "$file_path" "$temp_dir/"
            else
                echo "  ⚠️  File not found: $file_path"
            fi
        done
    fi
    
    # Create zip (using PowerShell on Windows or zip command on Unix)
    if command -v zip &> /dev/null; then
        local output_path
        output_path="$(pwd)/dist/$bundle_name"
        (cd "$temp_dir" && zip -r "$output_path" .)
    elif command -v pwsh &> /dev/null; then
        # Create zip in temp location, then move it (avoids path translation issues)
        local temp_zip="$temp_dir/$bundle_name"
        (cd "$temp_dir" && pwsh -Command "Compress-Archive -Path * -DestinationPath '$bundle_name' -Force")
        mv "$temp_zip" "dist/$bundle_name"
    elif command -v powershell &> /dev/null; then
        # Create zip in temp location, then move it (avoids path translation issues)
        local temp_zip="$temp_dir/$bundle_name"
        (cd "$temp_dir" && powershell -Command "Compress-Archive -Path * -DestinationPath '$bundle_name' -Force")
        mv "$temp_zip" "dist/$bundle_name"
    else
        echo "❌ No zip utility found"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "✅ Bundle created: dist/$bundle_name"
    echo "bundle-path=dist/$bundle_name" >> "$GITHUB_OUTPUT"
    echo "bundle-name=$bundle_name" >> "$GITHUB_OUTPUT"
}

bundle_macos() {
    local binary_name="$1"
    local binary_path="$2"
    local include_files="$3"
    local output_name="$4"
    local bundle_id="$5"
    local app_name="$6"
    local icon_path="$7"
    local cargo_toml_path="$8"
    local working_directory="$9"
    
    # Set defaults
    if [ -z "$app_name" ]; then
        app_name="$binary_name"
    fi
    
    if [ -z "$bundle_id" ]; then
        bundle_id="com.example.${binary_name}"
    fi
    
    # Use metadata from cargo metadata if available
    local version="1.0.0"
    local description=""
    if [ -n "$CARGO_PKG_VERSION" ]; then
        version="$CARGO_PKG_VERSION"
    fi
    if [ -n "$CARGO_PKG_DESCRIPTION" ]; then
        description="$CARGO_PKG_DESCRIPTION"
    fi
    # Override app_name with package name if not explicitly set
    if [ "$app_name" = "$binary_name" ] && [ -n "$CARGO_PKG_NAME" ]; then
        app_name="$CARGO_PKG_NAME"
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
    
    # Convert and copy icon if provided
    if [ -n "$icon_path" ] && [ -f "$icon_path" ]; then
        echo "  🎨 Converting icon to ICNS format"
        local icns_path="$app_dir/Contents/Resources/AppIcon.icns"
        if convert_png_to_icns "$icon_path" "$icns_path"; then
            echo "  ✅ Icon converted successfully"
        else
            echo "  ⚠️  Icon conversion not available (sips/iconutil required on macOS)"
            echo "  📄 Including original PNG icon"
            cp "$icon_path" "$app_dir/Contents/Resources/AppIcon.png"
        fi
    fi
    
    # Copy additional files to MacOS directory (relative to working_directory)
    if [ -n "$include_files" ]; then
        for file in $include_files; do
            # Remove trailing slash to ensure consistent cp behavior
            file="${file%/}"
            local file_path="$working_directory/$file"
            if [ -e "$file_path" ]; then
                echo "  📄 Including: $file"
                cp -r "$file_path" "$app_dir/Contents/MacOS/"
            else
                echo "  ⚠️  File not found: $file_path"
            fi
        done
    fi
    
    # Determine icon file name for Info.plist
    local icon_file=""
    if [ -f "$app_dir/Contents/Resources/AppIcon.icns" ]; then
        icon_file="AppIcon"
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
    <string>$version</string>
    <key>CFBundleVersion</key>
    <string>$version</string>
EOF
    
    # Add icon file reference if available
    if [ -n "$icon_file" ]; then
        cat >> "$app_dir/Contents/Info.plist" <<EOF
    <key>CFBundleIconFile</key>
    <string>$icon_file</string>
EOF
    fi
    
    # Add description if available
    if [ -n "$description" ]; then
        cat >> "$app_dir/Contents/Info.plist" <<EOF
    <key>CFBundleGetInfoString</key>
    <string>$description</string>
EOF
    fi
    
    # Close the plist
    cat >> "$app_dir/Contents/Info.plist" <<EOF
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
    
    # Apply ad-hoc code signing to prevent "damaged" errors on macOS
    # This is required for Apple Silicon and modern macOS versions
    if command -v codesign &> /dev/null; then
        echo "  🔏 Applying ad-hoc code signature..."
        codesign --force --deep --sign - "$app_dir" 2>&1 || echo "  ⚠️  Ad-hoc signing failed (not critical)"
    fi
    
    echo "✅ Bundle created: $app_dir"
    echo "bundle-path=$app_dir" >> "$GITHUB_OUTPUT"
    echo "bundle-name=$bundle_name" >> "$GITHUB_OUTPUT"
}

bundle_macos_with_signing() {
    local binary_name="$1"
    local binary_path="$2"
    local include_files="$3"
    local output_name="$4"
    local sign_identity="$5"
    local bundle_id="$6"
    local app_name="$7"
    local icon_path="$8"
    local cargo_toml_path="$9"
    local working_directory="${10}"
    
    # First create the unsigned bundle
    bundle_macos "$binary_name" "$binary_path" "$include_files" "$output_name" "$bundle_id" "$app_name" "$icon_path" "$cargo_toml_path" "$working_directory"
    
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
