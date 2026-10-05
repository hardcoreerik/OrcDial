"""Check native framebuffer capture provenance and circular text bounds."""
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image

root = Path(sys.argv[1])
manifest = json.loads((root / 'manifest.json').read_text())
assert manifest['width'] == manifest['height'] == 240
for case in manifest['cases']:
    path = root / case['path']
    with Image.open(path) as image:
        assert image.size == (240, 240) and image.mode == 'RGBA', path
        assert image.getpixel((0, 0))[3] == 0, path
        assert image.getpixel((120, 120))[3] == 255, path
    with Image.open(root / 'raw' / path.name) as raw:
        assert raw.size == (240, 240) and raw.mode == 'RGB', path
        assert hashlib.sha256(raw.tobytes()).hexdigest() == case['pixel_sha256'], path
        if case['group'] != 'selectors':
            for y in range(240):
                for x in range(240):
                    if raw.getpixel((x, y)) in ((255, 255, 255), (146, 182, 170)):
                        assert (x - 119.5)**2 + (y - 119.5)**2 < 119.5**2, (path, x, y)
    assert hashlib.sha256(path.read_bytes()).hexdigest() == case['png_sha256'], path
print(f"PASS: {len(manifest['cases'])} native captures, masks, hashes and circular foreground bounds")
