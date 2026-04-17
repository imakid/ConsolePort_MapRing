# ConsolePort Map Ring v1.1.0

A map navigation ring module for ConsolePort, providing a radial menu for navigating the World Map with a gamepad.

## What's Changed

- Added `## Version` field to TOC manifest

## Features

- **Radial Map Navigation**: Browse child map zones in a pie-menu ring overlay
- **Drill Down / Go Back**: Select a zone to drill into its children, press Back to navigate to the parent map
- **Pagination**: Automatically paginates when a map has more than 12 child zones (L1/R1 to flip pages)
- **Smart Hints**: Context-aware button hints (Select / Back / Close / Page navigation)
- **Combat Safe**: Automatically dismisses during combat lockdown and can reopen afterward
- **Configurable Scale & Font**: Adjustable via ConsolePort settings

## Requirements

- [ConsolePort](https://github.com/seblindfors/ConsolePort) (required dependency)

## Installation

1. Download and extract the `ConsolePort_MapRing` folder
2. Place it in your `Interface/AddOns/` directory
3. Restart World of Warcraft or `/reload`

## Usage

1. Open the World Map
2. Press **L3** (Left Stick click) to open the ring
3. Use the **left stick** to highlight a zone, then press **Accept** (Cross/A) to navigate
4. Press **Cancel** (Circle/B) to go back to the parent map
5. Use **L1/R1** to flip pages when there are more than 12 children
