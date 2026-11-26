#!/usr/bin/env python3
"""Render the approved Klash SVG into application assets (CairoSVG 2.8.2)."""
from io import BytesIO
from pathlib import Path
from xml.etree import ElementTree

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'klash/branding/app-icon.svg'


def main():
    glyph = ElementTree.parse(SOURCE).getroot()
    glyph.remove(glyph.find('{http://www.w3.org/2000/svg}image'))
    foreground = ElementTree.tostring(glyph)
    directory = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    outputs = [(directory / f'app_icon_{size}.png', size)
               for size in (16, 32, 64, 128, 256, 512, 1024)]
    outputs.append((ROOT / 'assets/images/icon.png', 550))
    for target, size in outputs:
        rendered = cairosvg.svg2png(bytestring=foreground, output_width=size * 4,
                                   output_height=size * 4)
        with Image.open(BytesIO(rendered)) as image, \
                Image.open(SOURCE.parent / f'tiles/tile_{size}.png') as tile:
            base = tile.convert('RGBA')
            overlay = image.resize((size, size), Image.Resampling.LANCZOS)
            result = Image.alpha_composite(base, overlay)
            result.putalpha(base.getchannel('A'))
            result.info.clear()
            result.save(target)
        print(target.relative_to(ROOT))


if __name__ == '__main__':
    main()
