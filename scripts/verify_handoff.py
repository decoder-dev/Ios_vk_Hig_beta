#!/usr/bin/env python3
"""Static artifact validator; does NOT claim iOS app compiles."""
from pathlib import Path
from xml.etree import ElementTree as ET
import csv, json
root=Path(__file__).resolve().parent.parent
assert (root/'PROMPT_FOR_CURSOR.md').is_file()
assert (root/'AGENTS.md').is_file()
assert len(list((root/'design/boards').glob('*.png'))) == 4
assert len(list((root/'design/screens').glob('*.png'))) == 16
assert len(list((root/'design/wireframes').glob('S*.svg'))) == 44
assert len(list((root/'design/wireframes_dark').glob('*.svg'))) == 8
with (root/'docs/FEATURE_MATRIX.csv').open(encoding='utf-8-sig',newline='') as f:
    rows=list(csv.DictReader(f))
assert len(rows)==44, len(rows)
assert len(set(r['id'] for r in rows))==44
for svg in (root/'design/wireframes').glob('*.svg'):
    ET.parse(svg)
json.loads((root/'design/tokens.json').read_text(encoding='utf-8'))
print(f'PASS: 4 boards, 16 reference crops, 44 screen SVGs, 8 dark SVGs, {len(rows)} registry screens.')
print('NOTE: This is a documentation/artifact validation only, not a Swift build or UI test.')
