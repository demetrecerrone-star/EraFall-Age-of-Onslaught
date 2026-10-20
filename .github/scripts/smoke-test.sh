#!/usr/bin/env bash
set -euo pipefail

APK='build/EraFall-release.apk'
PKG='com.dabsky.erafall'

dump_diagnostics() {
  echo '---- Android foreground activity ----' >&2
  adb shell dumpsys activity activities 2>/dev/null |
    grep -E 'mResumedActivity|topResumedActivity' | tail -n 5 >&2 || true
  echo '---- EraFall and Android crash logs ----' >&2
  adb logcat -d -v brief -s godot:V Godot:V GodotEngine:V AndroidRuntime:E ActivityManager:E 2>/dev/null |
    tail -n 120 >&2 || true
}

fail() {
  echo "EraFall Android smoke test failed: $1" >&2
  dump_diagnostics
  exit 1
}

app_running() {
  adb shell pidof "$PKG" >/dev/null 2>&1
}

wait_for_app() {
  for ((attempt=1; attempt<=30; attempt++)); do
    if app_running; then return 0; fi
    sleep 2
  done
  fail 'the game process did not start after launch'
}

wait_for_marker() {
  local marker="$1"
  local label="$2"
  for ((attempt=1; attempt<=60; attempt++)); do
    # Read every log line; grep -q can prematurely close the pipe with pipefail.
    if adb logcat -d -v raw 2>/dev/null | grep -F "$marker" > /dev/null; then
      echo "Verified $label."
      return 0
    fi
    if ! app_running; then
      fail "the game exited while waiting for $label"
    fi
    sleep 2
  done
  fail "timed out waiting for $label ($marker)"
}

test -s "$APK"
adb wait-for-device
adb install -r "$APK"
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 || fail 'could not launch the game'
wait_for_app

# Do not interact with Godot's boot splash. Readiness markers flush in release.
wait_for_marker 'ERAFALL_CI_TITLE_READY' 'the title menu'
sleep 2
mkdir -p build
adb exec-out screencap -p > build/erafall-title-emulator.png

DISPLAY_SIZE="$(adb shell wm size | tr -d '\r' | sed -n 's/.*: //p' | tail -n 1)"
[[ "$DISPLAY_SIZE" =~ ^[0-9]+x[0-9]+$ ]] || fail "unexpected display size: $DISPLAY_SIZE"
WIDTH="$(printf '%s' "$DISPLAY_SIZE" | cut -d x -f 1)"
HEIGHT="$(printf '%s' "$DISPLAY_SIZE" | cut -d x -f 2)"

# The current bottom menu uses 89%-97% of the display; old 85% tap missed Play.
# If approved poster assets exist, Play is instead centered near 75% height.
if [[ -f assets/branding/title_background.png && -f assets/ui/approved_play.png &&
      -f assets/ui/approved_upgrades.png && -f assets/ui/approved_collection.png &&
      -f assets/ui/approved_settings.png ]]; then
  adb shell input tap "$(( WIDTH * 50 / 100 ))" "$(( HEIGHT * 75 / 100 ))"
else
  adb shell input tap "$(( WIDTH * 14 / 100 ))" "$(( HEIGHT * 93 / 100 ))"
fi
wait_for_marker 'ERAFALL_CI_GAMEPLAY_READY' 'the playable stage'
sleep 2

# Exercise the native Android touch path, not just synthesized GDScript tests.
adb shell input swipe "$(( WIDTH * 48 / 100 ))" "$(( HEIGHT * 63 / 100 ))" \
  "$(( WIDTH * 78 / 100 ))" "$(( HEIGHT * 63 / 100 ))" 450
wait_for_marker 'ERAFALL_CI_STEERING_RECEIVED' 'Android drag steering'
adb exec-out screencap -p > build/erafall-gameplay-emulator.png
app_running || fail 'the game exited after gameplay swipe'
if adb logcat -d -s AndroidRuntime:E 2>/dev/null | grep -F "Process: $PKG" > /dev/null; then
  fail 'Android logged an EraFall process crash'
fi
echo 'Signed EraFall APK installed, drew title/gameplay screens and responded to Android touch steering.'
