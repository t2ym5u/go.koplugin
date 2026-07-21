# go.koplugin

A Go plugin for [KOReader](https://github.com/koreader/koreader).

## Screenshot

*(Screenshot to be added.)*

## Rules

Two players alternate placing black and white stones on grid intersections. A stone (or connected group) is captured and removed when it has no remaining liberties (empty adjacent intersections). The player controlling the larger territory at the end wins.

## Concept

The classic territory-and-capture board game, played pass-and-play on a single device.

## Features

- **Multiple board sizes**
- **Capture detection** — stones/groups removed automatically when surrounded
- **Auto-save** — in-progress game restored on next launch

## Controls

| Action | How |
|--------|-----|
| Place a stone | Tap an intersection |
| New game | Tap **New game** |
| Show rules | Tap **Rules** |

## Installation

1. Download `go.koplugin.zip` from the [latest release](../../releases/latest).
2. Extract into the `plugins/` folder of your KOReader data directory.
3. Restart KOReader.
4. Open the menu → **Tools** → **Go**.

## License

GPL-3.0 — see [LICENSE](LICENSE).
