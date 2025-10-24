use std::env;
use std::fs;

fn main() {
    // Get the directory where the executable is located
    let exe_path = env::current_exe()
        .expect("Failed to get current executable path");
    let exe_dir = exe_path.parent()
        .expect("Failed to get executable directory");
    
    // Construct the path to the hello.txt file
    let hello_file = exe_dir.join("assets").join("hello.txt");
    
    println!("Looking for hello.txt at: {}", hello_file.display());
    
    // Read and print the contents of hello.txt
    match fs::read_to_string(&hello_file) {
        Ok(contents) => {
            println!("Successfully read file!");
            println!("Content: {}", contents);
        }
        Err(e) => {
            eprintln!("Error reading file: {}", e);
            eprintln!("Attempted path: {}", hello_file.display());
            std::process::exit(1);
        }
    }
}
