# The Thinking Gungeon

A pixel-art top-down duel that introduces a stronger enemy planning method each level. Built with Godot 4.4.

## Run

Open this folder in Godot 4.4 or newer and press **F6** on `main.tscn`, or run:

```sh
godot --path .
```

## Desktop downloads

- **Windows x64:** Extract `build/thinking-gungeon-windows.zip`, then run `thinking-gungeon-windows.exe`. Keep the `.exe` and `.pck` in the same folder.
- **macOS (Intel and Apple Silicon):** Extract `build/thinking-gungeon-macos.zip`, move `The Thinking Gungeon.app` to Applications, then open it. This build is ad hoc signed but not notarized; if macOS blocks the first launch, Control-click the app and choose **Open**.

The desktop exports use the Godot 4.4.1 release templates. They were verified as packages on Linux; native Windows and macOS launch checks require those systems.

## Controls

| Desktop | Action |
| --- | --- |
| WASD | Move, including diagonals |
| Mouse | Aim |
| Left click | Fire |
| Left Shift | Leap in the current movement direction |
| Arrow keys / Space | Alternate aim / fire controls |
| Tab | Toggle the enemy's live planning display |
| Escape | Pause |

On an Android gaming handheld, use the **left stick** to move, **right stick** to aim, **right trigger** for one shot per press, **left trigger** to leap, **Y** to toggle planning, and **Start** to pause. The project is configured for Android landscape.
On lesson, pause, and result cards, **tap the button** or press **A/Start** to continue.

An ARM64 debug APK is available at `build/thinking-gungeon-android.apk`. Copy it to the handheld and install it through your device's file manager. It is signed with a development key for testing. The project includes an **Android Handheld** export preset so you can rebuild it in Godot after configuring the Android SDK and export templates. Physical handheld controls still need a device check.

Defeat the single enemy to unlock the next level. Progress is saved between launches. Debug builds expose every level in the menu for testing. The Menu button, Escape, or Start opens the level picker and controls. Cover blocks movement and bullets. Radar in levels 2–4 gives the enemy only intermittent position fixes. Levels 9–12 add projectile dodging, aim anticipation, escape-space scoring, and particle-aware minimax in sequence; each earlier score remains active at its balanced weight. Tab/Y expands live planning details in the telemetry strip below the arena.

Choose **Versus** from the menu to select two different level enemies and watch their AIs fight in a shared arena. The cyan fighter starts on the left, the coral fighter on the right. Press **Tab/Y** during a match to show or hide both algorithm visuals. Versus matches do not change campaign progress.

Character sprites are original procedural pixel art in `art/characters/rogue.png` and `art/characters/robot.png`. Their reproducible source is `art/characters/generate_sheets.py`.
