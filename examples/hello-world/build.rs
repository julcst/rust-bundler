fn main() {
    // Only compile Windows resources when building for Windows
    #[cfg(target_os = "windows")]
    {
        // Use winres to embed icon and version information on Windows
        let mut res = winres::WindowsResource::new();
        
        // Set icon if icon.ico exists
        // Note: Convert icon.png to icon.ico first:
        // convert icon.png -define icon:auto-resize=256,128,96,64,48,32,16 icon.ico
        if std::path::Path::new("icon.ico").exists() {
            res.set_icon("icon.ico");
        }
        
        // Compile the resource file
        // winres automatically reads metadata from Cargo.toml
        if let Err(e) = res.compile() {
            println!("cargo:warning=Failed to compile Windows resources: {}", e);
        }
    }
}

