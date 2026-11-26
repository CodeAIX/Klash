# Klash application icon

Approved 2026-10-23: white continuous-corner tile, emerald-to-jade-to-mint
logo. The two bars and dot retain the geometry of FlClash's
`assets_source/images/icon/glyph.svg`, credited under the repository GPL-3.0
license. The green glyph remains vector artwork in `app-icon.svg`. The SVG references
the original macOS tile in `tiles/tile_1024.png`. The other tile sizes retain
their original scale-specific alpha masks, margins and subtle shadows.
Revision 4 replaces the approximate revision 3 corner path with these inherited
tiles; their original colored glyph pixels are filled with the neutral plate
color before the green vector glyph is composited.

Regenerate the committed macOS 16–1024 px catalog and 550 px About-page asset:

```sh
uv run --with cairosvg==2.8.2 --with pillow==13.0.0 python tool/klash/generate_icon.py
```

CairoSVG needs the system Cairo library. With Homebrew on Apple Silicon, prefix
the command with `DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib` if the loader
cannot find `libcairo.2.dylib`. The foreground uses 4× supersampling and Lanczos resampling; the background
is composited at its original pixel size, and its alpha channel is retained
exactly. The 550 px About background is derived from the 1024 px tile. Release CI consumes the committed PNGs; it needs no Cairo install.

The status-bar icon is a separate native renderer whose colors describe proxy
configuration and IP quality; the application icon does not change with state.
