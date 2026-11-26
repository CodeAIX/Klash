# Klash derivative notice

Klash (formerly Flash) is an unofficial derivative of [FlClash](https://github.com/chen08209/FlClash), maintained by CodeAIX. Renamed and modified 2026-11-06. Exact upstream and application versions are recorded in klash/upstream.json; Core and prism_ui are pinned submodules with complete corresponding sources included in each release.

The original GPL-3.0 LICENSE, copyright notices and third-party licenses remain. FlClash, mihomo, Flutter and all bundled projects retain attribution. The selected application icon has a green gradient background and two white diagonal bars with a dot. The approved per-size exports are preserved. Historical branding sources remain under klash/branding. No AiGuard source or artwork was copied. This revision does not change application icon artwork.

The macOS product is Klash.app / com.codeaix.klash, with a debug suffix in Debug. Updates point to CodeAIX/Klash. Upstream internal Dart modules, private channel/IPC identifiers and the FlClashCore executable remain compatibility details. Windows and Android are not Klash distribution targets.

## Behavior

- Green background: TUN configured on; blue: system proxy only; orange: neither. These are configuration indicators, not proof that every application is intercepted.
- White country text: excellent built-in IP quality; black: other/unknown/loading/failed quality. Old-IP results cannot turn a new IP white.
- Gray with the upstream-style logo: stopped/paused. Neutral with red F: exit lookup failure; F remains the failure indicator. Unknown country: --.
- The native badge remains 26×18pt with 6pt continuous corners and a calibrated 12.5pt Heavy appearance. Immutable glyph paths are prepared before the drawing callback. Redraw does not use NSString text layout. Missing preparation falls back to the logo. No global exception swallowing or Core lifecycle change is introduced.
- Independent ◎ controls select groups, nested automatic groups or nodes for monitoring. Original node switching, group navigation and delay display remain. The target persists locally, exits refresh every 60 seconds and quality is cached by IP for three days.
- Stable builds set APP_ENV=stable. macOS signing retains file-picker read/write entitlements.
- New remote backups use /Klash; restore tries /Klash, /Flash, then /FlClash on 404/409 only. Old files are never modified; other errors remain errors.

## Identity and migration

The new bundle ID has separate data and permissions. Export a backup from Flash and restore it in Klash. No active SQLite database is copied and no old preferences are overwritten. The monitored target may need to be selected again. Stop the old client before running the new one in normal network mode; both retain the same upstream network responsibilities. Historical Flash releases remain unchanged.

## Distribution

klash/runtime.patch and its explicit path list contain runtime, platform-identity, localization and regression changes against the pinned upstream. tool/klash reconstructs and validates the overlay. Docs, workflows and branding metadata are copied separately. Conflicts or failed checks stop publication.

Build Klash macOS generates arm64 and x86_64 DMGs with ad-hoc signatures, not notarization. Each includes GPL notices, its exact revision, SHA256SUMS and a corresponding complete source archive with pinned Core and prism_ui. Inherited upstream workflows under .github/upstream-workflows are reference material only. Historical dispatch filenames remain compatible IDs; displayed names and artifacts use Klash.

Rendering and regression tests do not replace long-running sleep/wake, display-switch or real-network acceptance. Distributors must provide exact corresponding source and necessary build scripts under applicable licenses.
