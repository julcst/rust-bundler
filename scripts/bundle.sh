#!/bin/bash

set -e

# Function to parse Cargo.toml and extract metadata
parse_cargo_toml() {
    local cargo_toml_path="$1"
    
    if [ ! -f "$cargo_toml_path" ]; then
        return 1
    fi
    
    # Extract package name
    CARGO_PKG_NAME=$(grep -m 1 '^name\s*=' "$cargo_toml_path" | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' ')
    
    # Extract version
    CARGO_PKG_VERSION=$(grep -m 1 '^version\s*=' "$cargo_toml_path" | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' ')
    
    # Extract description (optional)
    CARGO_PKG_DESCRIPTION=$(grep -m 1 '^description\s*=' "$cargo_toml_path" | sed 's/.*=\s*"\(.*\)".*/\1/' || echo "")
    
    # Extract authors (optional, first author only)
    CARGO_PKG_AUTHORS=$(grep -m 1 '^authors\s*=' "$cargo_toml_path" | sed 's/.*\[\s*"\(.*\)".*/\1/' | sed 's/".*$//' || echo "")
    
    export CARGO_PKG_NAME CARGO_PKG_VERSION CARGO_PKG_DESCRIPTION CARGO_PKG_AUTHORS
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
        local iconset_dir=$(mktemp -d)
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

# Function to convert PNG to ICO (Windows icon format)
convert_png_to_ico() {
    local png_path="$1"
    local ico_path="$2"
    
    if [ ! -f "$png_path" ]; then
        return 1
    fi
    
    # Check if ImageMagick convert is available
    if command -v convert &> /dev/null; then
        convert "$png_path" -define icon:auto-resize=256,128,96,64,48,32,16 "$ico_path"
        return 0
    fi
    
    # Check if icotool is available (Linux)
    if command -v icotool &> /dev/null; then
        icotool -c -o "$ico_path" "$png_path"
        return 0
    fi
    
    return 1
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
    
    # Parse Cargo.toml if provided
    if [ -n "$cargo_toml_path" ] && [ -f "$cargo_toml_path" ]; then
        echo "📋 Parsing metadata from: $cargo_toml_path"
        parse_cargo_toml "$cargo_toml_path"
        echo "  Package: $CARGO_PKG_NAME"
        echo "  Version: $CARGO_PKG_VERSION"
        [ -n "$CARGO_PKG_DESCRIPTION" ] && echo "  Description: $CARGO_PKG_DESCRIPTION"
        [ -n "$CARGO_PKG_AUTHORS" ] && echo "  Author: $CARGO_PKG_AUTHORS"
    fi
    
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
            bundle_linux "$binary_name" "$binary_path" "$include_files" "$output_name" "$icon_path" "$cargo_toml_path"
            ;;
        Darwin)
            if [ "$macos_sign" = "true" ]; then
                bundle_macos_with_signing "$binary_name" "$binary_path" "$include_files" "$output_name" "$macos_sign_identity" "$macos_bundle_id" "$macos_app_name" "$icon_path" "$cargo_toml_path"
            else
                bundle_macos "$binary_name" "$binary_path" "$include_files" "$output_name" "$macos_bundle_id" "$macos_app_name" "$icon_path" "$cargo_toml_path"
            fi
            ;;
        Windows)
            bundle_windows "$binary_name" "$binary_path" "$include_files" "$output_name" "$icon_path" "$cargo_toml_path"
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
    
    local bundle_name="${output_name}-linux.tar.gz"
    local temp_dir=$(mktemp -d)
    
    echo "📦 Creating Linux tar.gz bundle: $bundle_name"
    
    # Copy binary
    cp "$binary_path" "$temp_dir/$binary_name"
    chmod +x "$temp_dir/$binary_name"
    
    # Copy icon if provided
    if [ -n "$icon_path" ] && [ -f "$icon_path" ]; then
        echo "  🎨 Including icon: $icon_path"
        cp "$icon_path" "$temp_dir/${binary_name}.png"
    fi
    
    # Generate .desktop file if we have metadata
    if [ -n "$cargo_toml_path" ] && [ -f "$cargo_toml_path" ]; then
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
    
    # Copy additional files
    if [ -n "$include_files" ]; then
        for file in $include_files; do
            # Remove trailing slash to ensure consistent cp behavior
            file="${file%/}"
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
    local icon_path="$5"
    local cargo_toml_path="$6"
    
    local bundle_name="${output_name}-windows.zip"
    local temp_dir=$(mktemp -d)
    
    echo "📦 Creating Windows zip bundle: $bundle_name"
    
    # Copy binary
    cp "$binary_path" "$temp_dir/${binary_name}.exe"
    
    # Convert and copy icon if provided
    if [ -n "$icon_path" ] && [ -f "$icon_path" ]; then
        echo "  🎨 Converting icon to ICO format"
        local ico_path="$temp_dir/${binary_name}.ico"
        if convert_png_to_ico "$icon_path" "$ico_path"; then
            echo "  ✅ Icon converted successfully"
        else
            echo "  ⚠️  Icon conversion not available (ImageMagick or icotool required)"
            echo "  📄 Including original PNG icon"
            cp "$icon_path" "$temp_dir/${binary_name}.png"
        fi
    fi
    
    # Generate resource files if we have metadata
    if [ -n "$cargo_toml_path" ] && [ -f "$cargo_toml_path" ]; then
        echo "  📄 Generating Windows resource files (.rc)"
        local version="${CARGO_PKG_VERSION:-1.0.0}"
        local description="${CARGO_PKG_DESCRIPTION:-$binary_name}"
        local company="${CARGO_PKG_AUTHORS:-}"
        local product_name="${CARGO_PKG_NAME:-$binary_name}"
        
        # Convert version to Windows format (e.g., 1.0.0 -> 1,0,0,0)
        local version_comma=$(echo "$version" | sed 's/\./, /g')
        # Ensure we have 4 version components
        local version_parts=$(echo "$version_comma" | tr ',' '\n' | wc -l)
        while [ "$version_parts" -lt 4 ]; do
            version_comma="$version_comma, 0"
            version_parts=$((version_parts + 1))
        done
        
        # Create a .rc file template
        cat > "$temp_dir/${binary_name}.rc" <<EOF
#include <windows.h>

// Icon
IDI_ICON1 ICON "${binary_name}.ico"

// Version Information
VS_VERSION_INFO VERSIONINFO
 FILEVERSION ${version_comma}
 PRODUCTVERSION ${version_comma}
 FILEFLAGSMASK 0x3fL
 FILEFLAGS 0x0L
 FILEOS VOS_NT_WINDOWS32
 FILETYPE VFT_APP
 FILESUBTYPE 0x0L
BEGIN
    BLOCK "StringFileInfo"
    BEGIN
        BLOCK "040904b0"
        BEGIN
            VALUE "CompanyName", "${company}"
            VALUE "FileDescription", "${description}"
            VALUE "FileVersion", "${version}"
            VALUE "InternalName", "${binary_name}"
            VALUE "LegalCopyright", "Copyright"
            VALUE "OriginalFilename", "${binary_name}.exe"
            VALUE "ProductName", "${product_name}"
            VALUE "ProductVersion", "${version}"
        END
    END
    BLOCK "VarFileInfo"
    BEGIN
        VALUE "Translation", 0x409, 1200
    END
END
EOF

        # Create a README explaining how to use the .rc file
        cat > "$temp_dir/WINDOWS_RESOURCES_README.txt" <<EOF
Windows Resource Files
======================

This bundle includes Windows resource files (.rc) that can be used to embed
metadata and icons into your executable at build time.

To use these resources:

1. Copy ${binary_name}.rc to your project root
2. If you have an icon, copy ${binary_name}.ico to your project root
3. Add winres to your Cargo.toml build dependencies:

   [build-dependencies]
   winres = "0.1"

4. Create a build.rs file in your project root:

   fn main() {
       if cfg!(target_os = "windows") {
           let mut res = winres::WindowsResource::new();
           res.set_icon("${binary_name}.ico");
           res.compile().unwrap();
       }
   }

5. Rebuild your project

Note: The .rc file provided is for reference. The winres crate will handle
most of the metadata automatically from your Cargo.toml.

For more information, see: https://docs.rs/winres/
EOF
    fi
    
    # Copy additional files
    if [ -n "$include_files" ]; then
        for file in $include_files; do
            # Remove trailing slash to ensure consistent cp behavior
            file="${file%/}"
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
        local output_path="$(pwd)/dist/$bundle_name"
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
    local icon_path="$7"
    local cargo_toml_path="$8"
    
    # Set defaults
    if [ -z "$app_name" ]; then
        app_name="$binary_name"
    fi
    
    if [ -z "$bundle_id" ]; then
        bundle_id="com.example.${binary_name}"
    fi
    
    # Use metadata from Cargo.toml if available
    local version="1.0.0"
    local description=""
    if [ -n "$cargo_toml_path" ] && [ -f "$cargo_toml_path" ]; then
        version="${CARGO_PKG_VERSION:-1.0.0}"
        description="${CARGO_PKG_DESCRIPTION:-}"
        # Override app_name with package name if not explicitly set
        if [ "$app_name" = "$binary_name" ] && [ -n "$CARGO_PKG_NAME" ]; then
            app_name="$CARGO_PKG_NAME"
        fi
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
    
    # Copy additional files to MacOS directory
    if [ -n "$include_files" ]; then
        for file in $include_files; do
            # Remove trailing slash to ensure consistent cp behavior
            file="${file%/}"
            if [ -e "$file" ]; then
                echo "  📄 Including: $file"
                cp -r "$file" "$app_dir/Contents/MacOS/"
            else
                echo "  ⚠️  File not found: $file"
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
    local icon_path="$8"
    local cargo_toml_path="$9"
    
    # First create the unsigned bundle
    bundle_macos "$binary_name" "$binary_path" "$include_files" "$output_name" "$bundle_id" "$app_name" "$icon_path" "$cargo_toml_path"
    
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
