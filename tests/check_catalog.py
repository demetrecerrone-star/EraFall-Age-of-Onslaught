"""Cheap offline regression checks; does not replace a Godot editor import/test."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
script = (root/'scripts/EraCatalog.gd').read_text()
play_assets = sorted((root/'assets/ui').glob('play_*.svg'))
assert len(play_assets) == 7, f'Expected 7 Play styles, got {len(play_assets)}'
for id in ('stone','bronze','iron','medieval','industrial','modern','future'):
    assert f'"id": "{id}"' in script
    assert (root/f'assets/ui/play_{id}.svg').exists()
for name in ('upgrades','collection','settings'):
    assert (root/f'assets/ui/{name}.svg').exists()
assert 'com.dabsky.erafall' in (root/'export_presets.cfg').read_text()
for secret in ('ERAFALL_KEYSTORE_BASE64','ERAFALL_STORE_PASSWORD', 'ERAFALL_KEY_ALIAS','ERAFALL_KEY_PASSWORD'):
    assert secret in (root/'.github/workflows/android.yml').read_text()
print('Era catalog, unique button images, package ID and secret names verified')
