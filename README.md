# JazzHands

A radial app switcher for macOS, inspired by the emote wheel in Overwatch. Hold a key combo to summon a ring of your active apps, flick toward the one you want, and release to switch. No clicking, no dock hunting — just muscle memory.

![JazzHands Demo](demo.gif)

### Themes

Fully customizable — ships with several built-in presets:

<p>
<img src="ss/1.png" width="49%" /> <img src="ss/2.png" width="49%" />
</p>
<p>
<img src="ss/3.png" width="49%" /> <img src="ss/4.png" width="49%" />
</p>

## How to Run (ELI5)

You need a Mac running macOS 13 or later with the Xcode command-line tools installed.

```bash
# 1. Clone the repo
git clone <repo-url> && cd jazzhands

# 2. Build and install (puts JazzHands.app in ~/Applications)
bash build.sh

# That's it. JazzHands is now running in your menu bar (look for the icon).
```

On first launch you'll be asked to grant two permissions:

1. **Accessibility** — lets JazzHands listen for your hotkey and raise windows. Go to **System Settings → Privacy & Security → Accessibility** and toggle JazzHands on.
2. **Screen Recording** — lets JazzHands capture window thumbnails for Deep Orbit. Same path but under **Screen Recording**.

After granting both, restart JazzHands from the menu bar icon (Quit → relaunch, or just run `bash build.sh` again).

## Usage

### Primary Ring

| Action | What happens |
|--------|-------------|
| **Hold Set Key Combination** | Summons the radial ring of active apps |
| **Move mouse** | Highlights the app in that direction |
| **Release Option** | Switches to the highlighted app |
| **Quick tap** (< 200ms) | Toggles to the last-used app |
| **Tab** (while held) | Cycles selection clockwise |
| **Backtick** (while held) | Cycles selection counter-clockwise |

### Deep Orbit (Window Picker)

When you hover over a multi-window app for 500ms (configurable), a second ring fans out showing individual windows with thumbnails. Move outward to pick a specific window, or move to a different app to switch targets. Release to activate.

### Settings

Right-click (or click) the menu bar icon → **Settings** to configure:

- **Shortcut** — change the trigger key combo (default: Option + Space)
- **Appearance** — ring colors, glow, opacity, icon size, segment borders
- **Behavior** — hover delay, cursor sensitivity, dead zone, deep orbit toggle
- **Animation** — parent wedge slide on deep orbit entry
- **Presets** — save and load full appearance configurations

![JazzHands Demo](settings.png)

## Scripts

### `build.sh` — Local Development Build

Builds a debug version of JazzHands, installs it to `~/Applications`, and launches it immediately. If a running instance is detected it will be killed first. The bundle is signed with your Apple Development identity (falls back to ad-hoc if none is found).

```bash
bash build.sh
```

Use this for day-to-day development and testing.

### `release.sh` — Production Release Build

Compiles an optimized release build, creates a signed `.app` bundle and a `.dmg` installer in the `release/` directory. With a Developer ID Application certificate it will also notarize both artifacts via Apple's notary service.

```bash
# Full signed + notarized release (requires Developer ID Application certificate)
bash release.sh

# Local release build without notarization
bash release.sh --local
```

Before your first notarized release, store your credentials once:

```bash
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id YOUR_APPLE_ID \
  --team-id YOUR_TEAM_ID \
  --password YOUR_APP_SPECIFIC_PASSWORD
```

## Requirements

- macOS 13.0+
- Swift 5.9+ (Xcode 15+ or standalone toolchain)
