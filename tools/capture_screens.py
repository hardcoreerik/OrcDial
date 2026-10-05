"""Export production-renderer frames from the local doc_capture firmware.

No radio commands are sent: doc_capture builds with ORCDIAL_DEMO=1.
"""
import argparse
import hashlib
import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

import serial
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser()
parser.add_argument('--port', default='COM14')
parser.add_argument('--output', type=Path, default=Path('docs/screenshots'))
parser.add_argument('--resume', action='store_true', help='Reuse complete PNGs from this same capture build only.')
parser.add_argument('--only', help='Comma-separated screen slugs; write a separate output folder for a partial capture.')
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
(args.output / 'raw').mkdir(exist_ok=True)

dashboards = [
    (0, 'home', 'Home', 4), (1, 'fm', 'FM Radio', 1),
    (16, 'am', 'AM Radio', 1), (5, 'weather', 'Weather', 0),
    (8, 'airband', 'Airband', 0), (9, 'marine', 'Marine', 0),
    (6, 'cb', 'CB Radio', 2), (3, 'adsb', 'ADS-B', 4),
    (10, 'satellite', 'Satellite', 3), (7, 'lora', 'LoRa / Mesh', 4),
    (13, 'rf-lab', 'RF Lab', 3), (2, 'p25', 'P25 Radio', 2),
    (4, 'shortwave', 'Shortwave', 4), (15, 'pocsag', 'POCSAG', 4),
    (14, 'wifi', 'Wi-Fi', 4), (12, 'settings', 'Settings', 4),
]
styles = ['reel', 'dial', 'odometer', 'tape', 'split']
cases = []
def add(slug, title, group, view=2, dashboard=0, style=4, focus=0,
        content=0, pairing=0, demo=1, pending=0):
    command = f'ORCDIAL_DOC_SHOW {view} {dashboard} {style} {focus} {content} {pairing} {demo} {pending}'
    cases.append(dict(slug=slug, title=title, group=group, command=command,
                      dashboard=dashboard, style=styles[style], focus=focus,
                      content_view=content, demo=bool(demo), pending=bool(pending)))

cases.append(dict(slug='boot', title='Boot splash', group='primary', command='ORCDIAL_DOC_BOOT', demo=True))
add('home-demo', 'Home (demo)', 'primary', view=0)
add('home-offline', 'Home (offline)', 'primary', view=0, demo=0)
add('connection', 'Connection screen', 'primary', view=3)
add('connection-searching', 'Connection search preview', 'primary', view=3, pairing=1)
for state, name in enumerate(['unpaired', 'searching', 'trusted-offline', 'connected', 'disconnected', 'verification', 'forget-confirmation', 'upgrade', 'timeout']):
    cases.append(dict(slug='devices-'+name,title='Devices: '+name,group='devices',command=f'ORCDIAL_DOC_DEVICE {state} 0',demo=True))
for id, slug, name, style in dashboards:
    add('selector-' + slug, name + ' selector', 'selectors', view=1, dashboard=id, style=style)
    if id == 0:
        continue
    add('dashboard-' + slug, name, 'dashboards', dashboard=id, style=style)
    if id in (3, 7, 2, 15, 14):
        for content in range(1, 5):
            add(f'{slug}-view-{content}', f'{name} view {content + 1}', 'content-views',
                dashboard=id, style=style, content=content)
    if id in (16, 8, 10, 13, 4):
        for other_style in range(5):
            if other_style != style:
                add(f'{slug}-style-{styles[other_style]}', f'{name}: {styles[other_style]}',
                    'tuning-styles', dashboard=id, style=other_style)
        for focus, label in [(1, 'step'), (2, 'gain'), (4, 'volume')]:
            add(f'{slug}-focus-{label}', f'{name}: {label}', 'controls', dashboard=id, style=style, focus=focus)
    elif id == 1:
        for focus, label in [(1, 'step'), (4, 'volume')]:
            add('fm-focus-' + label, 'FM: ' + label, 'controls', dashboard=id, style=style, focus=focus)
        add('fm-pending', 'FM pending command preview', 'controls', dashboard=id, style=style, pending=1)
    elif id in (5, 9, 6):
        f, label = (3, 'squelch') if id == 6 else (4, 'volume')
        add(f'{slug}-focus-{label}', f'{name}: {label}', 'controls', dashboard=id, style=style, focus=f)
        if id == 6:
            add('cb-focus-volume', 'CB: volume', 'controls', dashboard=id, style=style, focus=4)

if args.only:
    requested = set(args.only.split(','))
    assert requested <= {case['slug'] for case in cases}, 'Unknown screen slug'
    cases = [case for case in cases if case['slug'] in requested]

port = serial.Serial(None, 921600, timeout=0.3, write_timeout=10)
port.dtr = False
port.rts = False
port.port = args.port
port.open()
def response(marker, seconds=20):
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        line = port.readline().decode('ascii', 'replace').strip()
        if line.startswith(marker):
            return line
        if line.startswith(('ORCDIAL_DOC_ERROR', 'ORCDIAL_CAPTURE_ERROR')):
            raise RuntimeError(line)
    raise TimeoutError(marker)
try:
    time.sleep(6)  # allow the normal five-second boot splash to finish
    port.reset_input_buffer()
    for index, case in enumerate(cases, 1):
        raw_path = args.output / 'raw' / (case['slug'] + '.png')
        if args.resume and raw_path.exists():
            with Image.open(raw_path) as saved:
                assert saved.size == (240, 240) and saved.mode == 'RGB', raw_path
                pixels = saved.tobytes()
        else:
            for attempt in range(3):
                try:
                    port.write(('\n' + case['command'] + '\n').encode())
                    header = response('ORCDIAL_CAPTURE_BEGIN')
                    assert 'width=240 height=240 format=RGB888 bytes=172800 ack=row' in header, header
                    pixels = bytearray()
                    for row in range(240):
                        data = bytearray()
                        deadline = time.monotonic() + 4
                        while len(data) < 720 and time.monotonic() < deadline:
                            data.extend(port.read(720 - len(data)))
                        if len(data) != 720:
                            raise RuntimeError(f'Truncated frame: {case["slug"]}, row {row}')
                        pixels.extend(data)
                        port.write(b'K')
                    response('ORCDIAL_CAPTURE_END')
                    break
                except (RuntimeError, TimeoutError):
                    if attempt == 2:
                        raise
                    print(f'Retrying {case["slug"]}', flush=True)
                    time.sleep(6)  # let the device abandon a missing row ACK
                    port.reset_input_buffer()
        # LovyanGFX bgr888_t stores bytes in r, g, b order despite its name.
        raw = Image.frombytes('RGB', (240, 240), bytes(pixels))
        raw.save(args.output / 'raw' / (case['slug'] + '.png'))
        # Preserve raw pixels separately. Alpha masks only the corners hidden
        # by the physical round LCD; no RF data or interface art is fabricated.
        mask = Image.new('L', raw.size, 0)
        ImageDraw.Draw(mask).ellipse((0, 0, 239, 239), fill=255)
        rounded = raw.convert('RGBA')
        rounded.putalpha(mask)
        path = args.output / (case['slug'] + '.png')
        rounded.save(path)
        case['pixel_sha256'] = hashlib.sha256(pixels).hexdigest()
        case['png_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        case['path'] = path.name
        print(f'[{index}/{len(cases)}] {case["slug"]}', flush=True)
finally:
    try:
        port.write(b'\nORCDIAL_DOC_EXIT\n')
    finally:
        port.close()

manifest = dict(width=240, height=240, transport='USB framebuffer export',
                captured_utc=datetime.now(timezone.utc).isoformat(),
                firmware_sha256=hashlib.sha256(Path('.pio/build/doc_capture/firmware.bin').read_bytes()).hexdigest(),
                capture_tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                base_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                source_sha256={str(p.as_posix()): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in sorted([Path('platformio.ini'), *Path('src').glob('*.[ch]pp'),
                                                *Path('assets').rglob('*.png')])},
                source='M5Dial doc_capture firmware, production UI renderer',
                note='Preview data only. No live RF readings or receiver control. Raw square frames preserve exported pixels; rounded PNGs mask physical LCD corners.',
                cases=cases)
(args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
font = ImageFont.load_default()
for group in dict.fromkeys(case['group'] for case in cases):
    items = [case for case in cases if case['group'] == group]
    cols = 4
    sheet = Image.new('RGB', (cols * 264, ((len(items)+cols-1)//cols) * 280), '#050f16')
    pen = ImageDraw.Draw(sheet)
    for index, case in enumerate(items):
        x, y = (index % cols) * 264 + 12, (index // cols) * 280 + 8
        im = Image.open(args.output / case['path'])
        sheet.paste(im, (x, y), im)
        pen.text((x, y+245), case['title'], font=font, fill='#e8f5f6')
    sheet.save(args.output / ('contact-' + group + '.png'))
lines = ['# OrcDial screen gallery', '',
         'Captured from the M5Dial using the production UI renderer. These are documentation previews, not proof of live RF reception or implementation of every dashboard action. Boot and offline states retain their normal labels; other previews are marked DEMO. Devices trust/connection states are display-only DEMO fixtures, not evidence of live pairing.', '',
         'Each image is 240 × 240. Transparent corners match the round display; `raw/` preserves unmasked framebuffer captures. The manifest records commands and hashes. Animation is captured as a single frame, not an animation recording.', '']
for group in dict.fromkeys(case['group'] for case in cases):
    lines += ['## ' + group.replace('-', ' ').title(), '', f'![{group}](contact-{group}.png)', '']
    for case in [c for c in cases if c['group'] == group]:
        lines += [f'- [{case["title"]}]({case["path"]})']
    lines += ['']
(args.output / 'README.md').write_text('\n'.join(lines).rstrip() + '\n', encoding='utf-8')
print(f'Captured {len(cases)} screens, manifest and gallery written.', flush=True)
