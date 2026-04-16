# Console Port Map Ring

A map navigation ring module for [ConsolePort](https://github.com/seblindfors/ConsolePort), providing a radial menu for navigating the World Map with a gamepad.

## Features

- **Radial Map Navigation**: Browse child map zones in a pie-menu ring overlay
- **Drill Down / Go Back**: Select a zone to drill into its children, press Back to navigate to the parent map
- **Pagination**: Automatically paginates when a map has more than 12 child zones
- **Smart Hints**: Context-aware button hints (Select / Back / Close / Page navigation)
- **Combat Safe**: Automatically dismisses during combat lockdown and can reopen afterward
- **Configurable Scale & Font**: Adjustable via ConsolePort settings

## Requirements

- [ConsolePort](https://github.com/seblindfors/ConsolePort) (required dependency)

## Installation

1. Download or clone this repository
2. Place the `ConsolePort_MapRing` folder in your `Interface/AddOns/` directory
3. Restart World of Warcraft or reload the UI (`/reload`)

## Usage

1. Open the World Map
2. Press the **Map Ring** binding (default: L3 / Left Stick click) to open the ring
3. Use the **left stick** to highlight a zone, then press **Accept** (Cross / A) to navigate into it
4. Press **Cancel** (Circle / B) to go back to the parent map
5. If the current map has more than 12 children, use **L1/R1** (PagePrev/PageNext) to flip pages

## Configuration

Available in ConsolePort settings:

| Setting | Default | Description |
|---------|---------|-------------|
| Map Ring Scale | 1.0 | Scale of the ring overlay (0.5 – 2.0) |
| Font Size | 13 | Font size of zone labels on the ring (8 – 20) |

## File Structure

```
ConsolePort_MapRing/
├── ConsolePort_MapRing.toc   # Add-on manifest
├── Database.lua               # Settings definitions
├── View/
│   ├── Ring.xml               # Frame/XML templates
│   ├── Ring.lua               # Main ring logic, secure environment, bindings
│   └── MapData.lua            # Map data model with caching and pagination
└── README.md
```

## License

This project is provided as-is for the World of Warcraft addon community. ConsolePort is developed by [Sebastian Lindfors](https://github.com/seblindfors).
