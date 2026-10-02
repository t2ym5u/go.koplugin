# Changelog

All notable changes to this project will be documented in this file.

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
