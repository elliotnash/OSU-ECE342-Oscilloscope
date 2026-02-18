//! This build script copies the `memory.x` file from the crate root into
//! a directory where the linker can always find it at build time.
//! For many projects this is optional, as the linker always searches the
//! project root directory -- wherever `Cargo.toml` is. However, if you
//! are using a workspace or have a more complicated build setup, this
//! build script becomes required. Additionally, by requesting that
//! Cargo re-run the build script whenever `memory.x` is changed,
//! updating `memory.x` ensures a rebuild of the application with the
//! new memory settings.

use std::env;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;

fn main() {
    // Check which chip feature is enabled
    // Features use CARGO_FEATURE_* environment variables (uppercase, underscores for hyphens)
    let has_rp2040 = env::var("CARGO_FEATURE_RP2040").is_ok();
    let has_rp2350 = env::var("CARGO_FEATURE_RP2350").is_ok();

    if !has_rp2040 && !has_rp2350 {
        panic!("One of features 'rp2040' or 'rp2350' must be enabled. Use --features rp2040 or --features rp2350");
    }
    if has_rp2040 && has_rp2350 {
        panic!("Features 'rp2040' and 'rp2350' are mutually exclusive. Use --no-default-features --features <chip> to switch");
    }

    let use_rp2040 = has_rp2040;

    // Put `memory.x` in our output directory and ensure it's
    // on the linker search path.
    let out = &PathBuf::from(env::var_os("OUT_DIR").unwrap());
    File::create(out.join("memory.x"))
        .unwrap()
        .write_all(include_bytes!("memory.x"))
        .unwrap();
    println!("cargo:rustc-link-search={}", out.display());

    // By default, Cargo will re-run a build script whenever
    // any file in the project changes. By specifying `memory.x`
    // here, we ensure the build script is only re-run when
    // `memory.x` is changed.
    println!("cargo:rerun-if-changed=memory.x");

    println!("cargo:rustc-link-arg-bins=--nmagic");
    println!("cargo:rustc-link-arg-bins=-Tlink.x");
    
    // link-rp.x is only needed for RP2040 (embassy-rp generates it when rp2040 feature is enabled)
    if use_rp2040 {
        println!("cargo:rustc-link-arg-bins=-Tlink-rp.x");
    }
    
    println!("cargo:rustc-link-arg-bins=-Tdefmt.x");
}
