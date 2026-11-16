<div align="center">

# 🪟 EasyMove for macOS

**Move and resize any window from ANYWHERE inside its body. No more hunting for invisible 2-pixel borders on 4K or 27-inch displays.**

Inspired by Linux KDE/Alt-Drag, built natively in Lua for [Hammerspoon](https://www.hammerspoon.org).

[![macOS](https://img.shields.io/badge/macOS-12.0+-blue?style=flat-square&logo=apple&logoColor=white)](https://apple.com/macos)
[![Hammerspoon](https://img.shields.io/badge/Hammerspoon-1.0+-orange?style=flat-square&logo=lua&logoColor=white)](https://www.hammerspoon.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square)](https://github.com/mukesh-devx/easymove-macos)

[Why EasyMove?](#-the-problem-it-solves) • [Features](#-features) • [Installation](#-installation) • [Usage](#-how-to-use) • [Configuration](#-configuration) • [Architecture](#-codebase-architecture)

---

</div>

## 🎯 The Problem it Solves

On large 27-inch monitors, 4K displays, and high-density Retina screens:
1. **Targeting tiny 2-pixel borders**: To resize a window in macOS, you have to carefully aim for a 1-to-2 pixel invisible boundary along the corners. On a high-resolution display, hitting this boundary is frustrating, breaks focus, and frequently misses.
2. **Long travel to title bars**: Moving a window requires scrolling your mouse all the way to the top title bar—often thousands of pixels away or hidden behind dense tab strips.

**EasyMove solves both completely.** Hold <kbd>⌥ Option</kbd> and click **anywhere** inside the window body to move or resize it directly.

---

## ✨ Features

- **⚡️ Move Anywhere**: Hold <kbd>⌥ Option</kbd> + **Left Click & Drag** anywhere inside any window to move it 1:1. No need to reach for the title bar.
- **📐 Resize Anywhere with Smart Quadrants**: Hold <kbd>⌥ Option</kbd> + **Right Click & Drag** anywhere inside a window. EasyMove automatically detects which quadrant you grabbed (Top-Left, Top-Right, Bottom-Left, Bottom-Right) and resizes that corner while keeping the opposite corner anchored!
- **💎 Apple-Grade Frosted Glass HUD**: Displays a live, translucent dimension pill (`1440 × 900` or position coordinates) that floats cleanly near your cursor with smooth fade-in and zero flicker.
- **📍 Active Corner Glow**: Highlights the active resizing corner with a subtle Apple Blue indicator dot so you always have spatial awareness of what's moving.
- **🖥️ 27-inch & Multi-Monitor Native**: Seamlessly transitions windows across display boundaries with mixed DPI scaling.
- **🌌 macOS Spaces Compatible**: Uses persistent `stationary` window collection behaviors so HUD elements never disappear during Space switches.
- **🚀 Ultra-Lightweight & Battery-Friendly**: Consumes **0% CPU** when idle. Input hooks only activate when your designated modifier key is held.

---

## 📋 Requirements

- **macOS 12.0 (Monterey)** or higher
- **Hammerspoon 1.0+** (tested and verified on 1.1.x)
  ```sh
  brew install --cask hammerspoon
  ```

---

## 🚀 Installation

### Automated 1-Click Install

Clone the repository and run the installer:

```sh
git clone https://github.com/mukesh-devx/easymove-macos.git
cd easymove-macos
./install.sh
```

The script automatically:
1. Links `easymove/` into your `~/.hammerspoon/` directory.
2. Backs up your existing `init.lua`.
3. Adds the clean loader block to `~/.hammerspoon/init.lua`.

Then reload Hammerspoon from the menu bar:
**Hammerspoon icon → Reload Config**

### Manual Install

```sh
ln -s "$(pwd)/easymove" ~/.hammerspoon/easymove
```

Add to `~/.hammerspoon/init.lua`:

```lua
local ok, em = pcall(require, "easymove")
if ok then
  em.start()
end
```

---

## 🎮 How to Use

| Action | Gesture | Visual Feedback |
| :--- | :--- | :--- |
| **Move Window** | Hold <kbd>⌥ Option</kbd> + **Left Click & Drag** anywhere inside window | `✥ x, y` coordinate pill |
| **Resize Window** | Hold <kbd>⌥ Option</kbd> + **Right Click & Drag** anywhere inside window | `⤡ w × h` dimension pill + glowing corner dot |

### Smart Quadrant Resizing

```
  Top-Left Quadrant             Top-Right Quadrant
┌───────────────────────────┬───────────────────────────┐
│ [⤡ Resizes Top-Left]     │      [⤡ Resizes Top-Right]│
│                           │                           │
│   Anchor: Bottom-Right    │    Anchor: Bottom-Left    │
├───────────────────────────┼───────────────────────────┤
│   Anchor: Top-Right       │    Anchor: Top-Left       │
│                           │                           │
│ [⤡ Resizes Bottom-Left]  │   [⤡ Resizes Bottom-Right]│
└───────────────────────────┴───────────────────────────┘
  Bottom-Left Quadrant          Bottom-Right Quadrant
```

- Click in the **Bottom-Right** half: Top-Left stays fixed, Bottom-Right expands/contracts with your mouse.
- Click in the **Top-Left** half: Bottom-Right stays fixed, Top-Left moves.
- Whichever direction you drag toward, the window follows naturally.

---

## ⚙️ Configuration

Pass custom options to `em.start()` in your `~/.hammerspoon/init.lua`:

```lua
local em = require("easymove")

em.start({
  -- Modifier key(s) to hold: "alt", "cmd", "ctrl", "shift", "fn"
  modifiers = { "alt" },               -- e.g. { "cmd", "alt" } or { "ctrl" }

  -- Mouse button mapping
  moveButton = "left",                 -- "left" or "right"
  resizeButton = "right",              -- "right" or "left"

  -- Minimum dimensions to prevent windows from shrinking to zero
  minWidth = 160,
  minHeight = 100,

  -- Raise window to front immediately on grab
  bringToFrontOnGrab = true,

  -- Visual feedback HUD
  showHUD = true,                      -- Live dimension pill
  showCornerGlow = true,               -- Active corner dot indicator

  -- Exclude specific applications by Bundle ID
  excludedApps = {
    -- "com.apple.finder",
  },

  -- Custom theme
  theme = {
    accent = "#0A84FF",                -- Highlight glow color
    font = ".AppleSystemUIFont",
    fontSize = 13,
    cornerRadius = 8,
  },

  -- Menu bar item
  menubar = true,
})
```

### Full Configuration Reference

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `modifiers` | `table` | `{"alt"}` | Modifier keys held to trigger move/resize. Accepts `alt`, `cmd`, `ctrl`, `shift`, `fn`. |
| `moveButton` | `string` | `"left"` | Mouse button for dragging windows (`"left"` or `"right"`). |
| `resizeButton`| `string` | `"right"`| Mouse button for resizing windows (`"right"` or `"left"`). |
| `minWidth` | `number` | `160` | Minimum allowed window width in points. |
| `minHeight` | `number` | `100` | Minimum allowed window height in points. |
| `bringToFrontOnGrab` | `boolean` | `true` | Automatically focuses and raises the grabbed window. |
| `showHUD` | `boolean` | `true` | Show floating dimension pill during drag. |
| `showCornerGlow` | `boolean` | `true` | Display active corner anchor indicator during resize. |
| `excludedApps`| `table` | `{}` | Array of bundle IDs never moved or resized. |
| `menubar` | `boolean` | `true` | Show native menu bar item with toggle and status. |

---

## 🛠️ Lua API

```lua
local em = require("easymove")

em.start(customConfig)
em.stop()
em.setEnabled(true)                    -- Enable or disable via hotkey/script
em.isEnabled()                         -- Returns current boolean state
em.isRunning()
```

---

## 🏗️ Codebase Architecture

```
easymove-hammerspoon/
├── easymove/
│   ├── init.lua          # Public API facade, lifecycle, and space watchers
│   ├── mover.lua         # Eventtap state machine for gesture tracking & input filtering
│   ├── resize_math.lua   # Pure geometry: quadrant calculations & coordinate math
│   ├── hud.lua           # Apple-style frosted dimension pill & corner canvas overlay
│   ├── menubar.lua       # Native menu bar item with template rendering & actions
│   ├── permissions.lua   # macOS Accessibility check and automatic recovery
│   ├── config.lua        # Default options, modifier normalization, deep merge
│   ├── util.lua          # Geometry & modifier verification utilities
│   └── log.lua           # Scoped logger
├── install.sh            # Automated installer & uninstaller script
├── LICENSE               # MIT License
└── README.md
```

> **Clean Architecture Note**: `resize_math.lua` and `config.lua` contain pure logic with zero dependencies on Hammerspoon (`hs.*`), ensuring mathematical accuracy and unit-testability.

---

## 🤝 Works Seamlessly with FancyZones

EasyMove and [FancyZones for macOS](https://github.com/mukesh-devx/fancyzones-macos) are designed to complement each other perfectly:
- Use **FancyZones** (<kbd>⇧ Shift</kbd> + title bar drag) for snapping windows into structured multi-zone grids.
- Use **EasyMove** (<kbd>⌥ Option</kbd> + click anywhere) for quick fluid adjustments and fine-grained resizing without aiming for 2-pixel borders.

---

## 📄 License

This project is open-source software licensed under the **[MIT License](LICENSE)**.
Free to use, customize, and contribute!
