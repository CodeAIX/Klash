# Klash 1.9.5 candidate

This branch integrates the fixed FlClash v0.9.5 release, including its pinned Core and prism_ui submodules. It preserves Klash's bundle ID, selected icon exports, monitor targets, badge colors, WebDAV fallback readers and macOS window handoff. It does not install, launch in normal network mode, or publish a release.

## Toolchain

Use Flutter 3.50.1, Go 1.27.1, Rust 1.99.0 and an Xcode 26 or newer SDK. The Swift compiler builds the retained menu/glyph implementation inside rust_api through `rust/build.rs`. Intel release builds retain `FLTEnableImpeller=false`. Private upstream Core, module and IPC names remain unchanged.

## Generate and verify

```sh
git submodule update --init --recursive
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
(cd plugins/rust_api && flutter_rust_bridge_codegen generate)
flutter analyze --no-fatal-infos
dart run tool/test.dart
bash tool/check_plugins.sh
cargo fmt --manifest-path plugins/rust_api/rust/Cargo.toml -- --check
cargo test --manifest-path plugins/rust_api/rust/Cargo.toml
flutter build macos --debug --dart-define=SAFE_MODE=true
python3 tool/klash/sync_upstream.py --validate-overlay
```

Use flutter_rust_bridge_codegen 2.13.0. Never edit generated localization or bridge files by hand. Runtime patch generation and reconstruction are described in [README.md](README.md). A successful reconstruction proves the declared overlay reproduces this candidate; future upstream compatibility still requires its own check.

## Review and packaging

Create a reviewable candidate PR, then dispatch `flash-macos.yml` on that exact branch with `publish=false`. Both macOS architectures must pass tests, native checks and package verification. Verify versions, bundle IDs, architectures, entitlements, signatures, asset hashes and complete source correspondence before release. The packages are ad-hoc signed and not notarized.

Keep the latest released tag intact. Formal publication needs the user's existing authorization or final approval of the concrete verified candidate. Installation and normal-mode network acceptance are separate from CI, package inspection and isolated native tests; never replace or restart the current proxy client to obtain them.

## Upstream changes

The retired `plugins/tray` and `plugins/window` paths are now under rust_api. Locale generation reads `arb/intl_zh.arb`, writes `lib/l10n/l10n_*.dart`, and uses Flutter gen-l10n. Upstream workflow snapshots are stored under `.github/upstream-workflows`; only Klash's own workflows are active.


## Local validation on 2026-11-26

The unmodified upstream baseline and the Klash candidate both built successfully on Apple Silicon. The final complete root run passed 5,507 tests with one skip because the test renderer does not support shader image filters. The Rust crate passed 150 tests. Plugin analysis/tests, Core checks/tests, root analysis, formatting and overlay reconstruction passed. The retained menu, glyph and C ABI harnesses passed, including 57,540 glyph draws. The three retained Swift sources and all selected app-icon PNG exports match the previous release byte for byte.

The local release bundle is 1.9.5 (2026112601), com.codeaix.klash, arm64 for both app and Core, with strict deep signature verification. These checks do not include normal-mode installation, real proxy routing, user interaction or long-running acceptance. The CI workflow builds both architectures without publication when dispatched with `publish=false`.

The Flutter release-index URL returned HTTP 404 during preparation, so CI clones the official 3.50.1 tag and verifies commit ae9b586f34a8443573f82ef57c3bf914a908cbf7 before bootstrapping it, matching the SDK used locally.
