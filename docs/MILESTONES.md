# EraFall Milestones

## Prototype 0.1: underway
- [x] Seven eras stored in an extendable data catalog
- [x] Per-era Play button PNG-independent SVG asset; independent Upgrades/Collection/Settings button assets
- [x] Procedurally assembled low-poly 3D arena and units (no external asset dependency)
- [x] Drag left/right, arrow keys, automated attacks, ally gates, enemies, miniboss, boss
- [x] Victory unlocks next era, saves progress, changes title Play button on era entry
- [x] Gold-based attack upgrades and an unlockable pet collection
- [x] Android release-signing workflow with keystore verification, signature check, emulator install/launch
- [ ] Import original Dabsky emblem and approved title mockup as separate actual source images
- [ ] First successful signed APK from GitHub Actions, verified on Android emulator
- [ ] Audio and procedural combat animations beyond prototype level
- [ ] Art pass: bespoke character models, VFX, era terrain, bosses, and animations

## Design rules
Only the Play button changes era style; the other menu buttons remain stable. Preserve package ID and keystore across versions. Do not publish unsigned APKs as production builds.
