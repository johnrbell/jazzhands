# Orbit

A radial app switcher for macOS. Hold a pre-defined key combo to summon a circular ring of your active apps, move the mouse to highlight, and release to switch.

![Orbit Demo](demo.gif)

## Requirements

- macOS 13.0+
- Xcode 15+ or Swift 5.9+
- Accessibility permission (prompted on first launch)

## Build & Run

**With Swift Package Manager:**

```bash
swift build
.build/debug/Orbit
```

**With Xcode:**

```bash
open Orbit.xcodeproj
```

Then build and run the Orbit scheme (⌘R).

## How It Works

### Primary Orbit (Tier 1)
- **Option + Space (hold):** Shows the radial ring of all active apps (apps with at least one visible window)
- **Mouse movement:** The cursor is hidden and locked to center. Movement direction highlights the corresponding app segment
- **Release Option:** Switches to the highlighted app and dismisses the UI
- **Quick tap:** Toggles to the last used app (like a fast Cmd+Tab)

### Deep Orbit (Tier 2)
- **Hover 500ms** on a multi-window app: A second concentric ring appears with window thumbnails
- **Move outward** into the outer ring to select a specific window
- **Release** to bring that exact window to front

## Architecture

| File | Purpose |
|------|---------|
| `OrbitApplication.swift` | SwiftUI app entry point (menu bar agent) |
| `AppDelegate.swift` | Global hotkey listener, lifecycle management |
| `WindowManager.swift` | CGWindowList + NSRunningApplication queries |
| `Models.swift` | OrbitApp / OrbitWindow data models |
| `OrbitViewModel.swift` | Angle → segment mapping, state machine, hover timers |
| `OrbitView.swift` | SwiftUI radial UI with glow effects |
| `OverlayWindowController.swift` | Transparent overlay window, mouse locking via CGWarpMouseCursorPosition |

## Permissions

Orbit requires **Accessibility** permission to:
- Listen for global hotkeys (Option + Space) when other apps are focused
- Raise specific windows via the Accessibility API

On first launch, macOS will prompt you. You can also enable it manually in **System Settings → Privacy & Security → Accessibility**.

## Segment Selection Math

The mouse vector `(dx, dy)` from center is converted to an angle:

```
θ = atan2(dy, dx)
```

Normalized to `[0, 2π)`, then mapped to a segment index:

```
index = floor(θ / (2π / n)) % n
```

where `n` is the number of active apps.
