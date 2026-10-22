#!/usr/bin/env python3
"""Check final bundles without printing private key or license contents."""
import base64
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[1]
config = json.loads((root / 'Resources/Commerce.json').read_text())
private = root / '.private'
secrets = []
if (private / 'signing-key').exists():
    key = (private / 'signing-key').read_bytes()
    assert len(key) == 32
    secrets.extend([key, base64.b64encode(key)])
for inventory in private.glob('*.txt'):
    secrets.extend(line for line in inventory.read_bytes().splitlines() if line)
expected = {
    'Contents/Info.plist', 'Contents/MacOS/PadDock',
    'Contents/Resources/Commerce.json', 'Contents/Resources/AppIcon.icns',
    'Contents/_CodeSignature/CodeResources',
}
assert len(sys.argv) > 1, 'Supply final app bundle paths'
for name in sys.argv[1:]:
    app = pathlib.Path(name)
    files = [p for p in app.rglob('*') if p.is_file()]
    assert {str(p.relative_to(app)) for p in files} == expected, 'Unexpected app contents'
    assert json.loads((app / 'Contents/Resources/Commerce.json').read_text()) == config
    for file in files:
        data = file.read_bytes()
        assert not any(secret in data for secret in secrets), 'Private material found in bundle'
print(f'Commerce artifacts verified: {len(sys.argv)-1} bundles, matching public configuration, expected contents, no local private material.')
