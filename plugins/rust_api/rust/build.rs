use std::{env, path::PathBuf, process::Command};

fn output(args: &[&str]) -> String {
    let result = Command::new("xcrun")
        .args(args)
        .output()
        .expect("run xcrun");
    assert!(result.status.success(), "xcrun failed: {:?}", result);
    String::from_utf8(result.stdout)
        .expect("xcrun output")
        .trim()
        .into()
}

fn main() {
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("macos") {
        return;
    }
    let source = PathBuf::from("src/tray/macos/klash");
    println!("cargo:rerun-if-changed={}", source.display());
    let out = PathBuf::from(env::var_os("OUT_DIR").expect("OUT_DIR"));
    let arch = match env::var("CARGO_CFG_TARGET_ARCH").as_deref() {
        Ok("aarch64") => "arm64",
        Ok("x86_64") => "x86_64",
        _ => panic!("unsupported macOS architecture"),
    };
    let swift = output(&["--find", "swiftc"]);
    let sdk = output(&["--sdk", "macosx", "--show-sdk-path"]);
    let root = env::current_dir().expect("crate root");
    let status = Command::new(&swift)
        .args([
            "-emit-library",
            "-static",
            "-O",
            "-module-name",
            "KlashNative",
        ])
        .args(["-target", &format!("{arch}-apple-macosx12.0"), "-sdk", &sdk])
        .args(["-file-prefix-map", &format!("{}=.", root.display())])
        .args(
            [
                "TrayMenu.swift",
                "TrayMenuItemView.swift",
                "KlashStatusImage.swift",
                "KlashBridge.swift",
            ]
            .map(|name| source.join(name)),
        )
        .arg("-o")
        .arg(out.join("libKlashNative.a"))
        .status()
        .expect("compile Klash native menu and glyphs");
    assert!(status.success(), "Klash Swift compilation failed");
    let runtime = PathBuf::from(swift)
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .join("lib/swift/macosx");
    println!("cargo:rustc-link-search=native={}", out.display());
    println!("cargo:rustc-link-search=native={}", runtime.display());
    println!("cargo:rustc-link-search=native=/usr/lib/swift");
    println!("cargo:rustc-link-lib=static=KlashNative");
    println!("cargo:rustc-link-arg=-Wl,-rpath,/usr/lib/swift");
}
