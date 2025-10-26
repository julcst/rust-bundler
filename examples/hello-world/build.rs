fn main() {
    // Only compile Windows resources when building for Windows
    #[cfg(target_os = "windows")]
    {
        // Use winres to embed icon and version information on Windows
        // This requires adding winres to build-dependencies in Cargo.toml
        
        // Uncomment the following lines to enable Windows resource embedding:
        // let mut res = winres::WindowsResource::new();
        // res.set_icon("icon.ico");
        // res.compile().unwrap();
        
        // Note: You'll need to convert icon.png to icon.ico first:
        // convert icon.png -define icon:auto-resize=256,128,96,64,48,32,16 icon.ico
        
        println!("cargo:warning=Windows resource embedding is disabled by default.");
        println!("cargo:warning=To enable it:");
        println!("cargo:warning=1. Add 'winres = \"0.1\"' to [build-dependencies] in Cargo.toml");
        println!("cargo:warning=2. Convert icon.png to icon.ico");
        println!("cargo:warning=3. Uncomment the winres code in build.rs");
    }
}
