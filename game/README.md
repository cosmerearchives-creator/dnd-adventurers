# DnD Adventurers — Godot wilderness prototype

This is the new **Godot 4 / GDScript** gameplay project. The existing `app/` Android updater remains unchanged.

## Play locally

Open `game/project.godot` with Godot 4.3 or newer and press **Run Project**.

- Move with WASD / arrow keys or a left-side touchscreen drag joystick.
- Attacks target the nearest monster automatically.
- Collect cyan experience orbs to increase health and damage.
- Survive ten minutes to win; tap or press R to restart after defeat.

## Current scope

The first gameplay slice includes a scrolling forest, free movement, wolves, goblins, skeletons, wave spawning, health, experience, leveling and a ten-minute objective. **Graphics are procedural placeholders, not Blender-rendered 2.5D assets.** Trees and stones are decorative at this stage and do not yet block movement.

## Next steps

1. Add Godot Android export templates and a release-signing pipeline.
2. Replace procedural shapes with Blender-rendered eight-direction character atlases and matching forest tiles.
3. Add collision, animation, weapon variety, richer monster AI and a proper touch HUD.
4. Integrate the game with the existing native update flow, preserving the Android application ID and release signing identity.

The existing native APK is **not** yet the Godot game. Do not distribute a Godot export as an in-place update until package/signing compatibility is established.
