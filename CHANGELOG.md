# Changelog

All notable changes to this project will be documented in this file.

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
