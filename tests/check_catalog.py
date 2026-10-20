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

# Guard against the two visible regressions found on the first real phone build:
# missing SVG captions and a 3D camera that points at the horizon.
main = (root/'scripts/Main.gd').read_text()
assert 'caption = "PLAY"' in main
for title in ('UPGRADES', 'COLLECTION', 'SETTINGS'):
    assert f'caption = "{title}"' in main
assert 'label.mouse_filter = Control.MOUSE_FILTER_IGNORE' in main
assert re.search(
    r'add_child\(camera\)\s+camera\.look_at\(',
    main
), 'Camera must be in scene tree before look_at'
assert 'func _add_approved_title_art()' in main
for path in (
    'res://assets/branding/title_background.png',
    'res://assets/ui/approved_play.png',
    'res://assets/ui/approved_upgrades.png',
    'res://assets/ui/approved_collection.png',
    'res://assets/ui/approved_settings.png',
):
    assert path in main, f'Approved art hook missing: {path}'
print('Mobile camera orientation, menu label fallback, and approved artwork hooks verified')

# Keep Android release readiness markers and CI plumbing in sync.
project = (root / 'project.godot').read_text()
smoke = (root / '.github/scripts/smoke-test.sh').read_text()
workflow = (root / '.github/workflows/android.yml').read_text()
assert 'run/flush_stdout_on_print=true' in project
for marker in ('ERAFALL_CI_TITLE_READY', 'ERAFALL_CI_GAMEPLAY_READY', 'ERAFALL_CI_STEERING_RECEIVED'):
    assert marker in main and marker in smoke, f'Readiness marker missing: {marker}'
assert 'Enable KVM hardware acceleration' in workflow
assert 'HEIGHT * 93 / 100' in smoke, 'Android fallback Play button coordinates regressed'
print('Android release-readiness, emulator KVM and menu tap checks verified')
