# Changelog

All notable changes to this project will be documented in this file.

## [1.2.3] - 2026-11-03

### Changed
- Picks up game-common 1.11.0: the shared on-screen keyboard (where used)
  gives every key the same letter size, and the no-repeat history helper.

## [1.2.2] - 2026-11-02

### Changed
- Picks up game-common 1.10.0: the shared Tools → Games menu also lists
  the games' new "· multiplayer" entries under Party & quiz.

## [1.2.1] - 2026-11-02

### Changed
- Listed under **Tools → Games**, grouped by category, instead of its own
  entry in the Tools menu (game-common 1.9.1).

## [1.2.0] - 2026-10-30

### Added
- "New game" once the game is over (two passes in a row): the action bar
  shows it in place of Pass, so the next game no longer needs the menu.

### Changed
- Redesigned play screen, in line with the other games: a full-width action
  bar and a larger board that fills the available room. The status line
  reads "size · Black to play · Captures: B0 W0" and wraps in landscape
  instead of being cut off.
- Title-bar menu in the same order as every other game: New game, "Size:
  9×9" (was a bare "9×9" after the opponent entry), Opponent, Pass, Rules.
- New README screenshot.

### Fixed
- Stones on the edge of the board were clipped. The margin around the grid
  was a fixed 4% of the board, smaller than a stone's radius on 9×9; it is
  now about half a cell, so edge stones are drawn whole.

## [1.1.2] - 2026-10-02

### Fixed
- `Black` and `White` became `Black side` and `White side`. `package.loaded`
  is keyed by module name alone, so every `require("i18n")` on the device
  resolves to one module and the first plugin loaded wins it. Every plugin's
  `i18n_fr.lua` merges into that one shared table, where plugins silently
  overwrite each other's translations. This plugin wants the French singular
  ("Noir", "Blanc") while chess, chesscourse, gomoku and othello want the
  plural ("Noirs", "Blancs"), and the chess form was winning -- so the side
  label here read "Noirs" in French. Distinct keys let both be right.

## [1.1.1] - 2026-10-01

### Fixed
- Picks up game-common v1.5.0. Play statistics were recorded under a key no
  tool could match: `ReaderUI`/`FileManager:registerModule()` rewrite a plugin
  instance's `name` to `reader<id>` / `filemanager<id>` right after it is
  built, so this game's sessions were split across two rows and neither
  carried its plugin id. Rows written under the old keys are merged back on
  first read. The same release brings the `stopPlugin()` /
  `deletePluginSettings()` hooks KOReader 2026.07 calls when a plugin is
  deleted from the device (PR #15240).

  No change to this plugin's own code -- it inherits all of it from the
  shared library.

## [1.1.0] - 2026-09-30

### Added
- **Computer opponent** (optional, from the options menu; it plays White so a
  solo player keeps the first move). A beginner, and honest about it: no
  search and no playouts, because a shallow search in Go is only as good as
  its ability to tell a live group from a dead one, and on an e-ink CPU that
  plays worse than clear rules of thumb. What it does understand is what
  beginners lose games to — captures on offer, its own groups in atari,
  stones played straight into capture, and above all never filling its own
  eyes. It beat a random legal-move player 19-1 over 20 games on 9×9, at
  0.001s per move.
