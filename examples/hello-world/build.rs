fn main() {
    // Only compile Windows resources when building for Windows
    #[cfg(target_os = "windows")]
    {
        use std::path::Path;

        // Use ico-builder to automatically generate icon.ico from icon.png
        let png_path = Path::new("icon.png");
        let ico_path = Path::new("icon.ico");

        // Generate ICO from PNG if PNG exists and ICO doesn't exist or is older
        if png_path.exists() {
            let should_generate = !ico_path.exists() || {
                let png_modified = std::fs::metadata(png_path)
                    .and_then(|m| m.modified())
                    .ok();
                let ico_modified = std::fs::metadata(ico_path)
                    .and_then(|m| m.modified())
                    .ok();
                
                match (png_modified, ico_modified) {
                    (Some(png_time), Some(ico_time)) => png_time > ico_time,
                    _ => true,
                }
            };

            if should_generate {
                match ico_builder::build_ico_from_png(png_path, ico_path) {
                    Ok(_) => println!("cargo:warning=Generated icon.ico from icon.png"),
                    Err(e) => println!("cargo:warning=Failed to generate icon.ico: {}", e),
                }
            }
        }

        // Use winres to embed icon and version information on Windows
        let mut res = winres::WindowsResource::new();
        
        // Set icon if icon.ico exists (either pre-existing or just generated)
        if ico_path.exists() {
            res.set_icon("icon.ico");
        }
        
        // Compile the resource file
        // winres automatically reads metadata from Cargo.toml
        if let Err(e) = res.compile() {
            println!("cargo:warning=Failed to compile Windows resources: {}", e);
        }

        // Rerun build script if icon.png changes
        println!("cargo:rerun-if-changed=icon.png");
    }
}

