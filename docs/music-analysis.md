# Music Analysis Pipeline

## Overview

The music analysis pipeline extracts audio features using **Essentia**, builds a **similarity index** with **Annoy** (Approximate Nearest Neighbors), and provides CLI and TUI tools for querying similar tracks and running highlevel classifiers (genre, moods, danceability, etc.). The index is rebuilt weekly via a systemd timer.

## Architecture

- **`music-index`** (Python) — Scans a music directory, extracts feature vectors via Essentia's `streaming_extractor_music`, caches results by content hash, and builds an Annoy index with angular distance. Outputs `index.ann`, `tracks.jsonl`, and `meta.json` to `~/.cache/music-index/`.
- **`music-similar`** (Python) — Queries the prebuilt Annoy index for top-N neighbors of a given audio file or the currently playing track (via `playerctl`). Prints distance and path per result.
- **`music-highlevel`** (Python) — Runs Essentia's highlevel classifiers over audio files or directories. Emits human-readable or JSON output with genre, moods, danceability, and other taxonomies.
- **`music-tui`** (zsh) — fzf-based TUI wrapping `music-similar`, `music-highlevel`, and a collection profile view. Supports interactive browsing with similarity previews and inline playback via `mpv`.

## Salt State

- **`states/music_analysis.sls`** — Manages:
  - `python-annoy` (via `paru_install` macro)
  - Essentia streaming extractor binary tarball (via `curl_extract_tar`)
  - User systemd units: `music-index.service` and `music-index.timer`
  - Post-install validation (`essentia_streaming_extractor_music --help`)
- **`states/units/user/music-index.service`** — Oneshot systemd service running `%h/.local/bin/music-index`
- **`states/units/user/music-index.timer`** — Weekly trigger for the index rebuild
- **Feature gate:** `host.features.get('music_analysis')` in `states/system_description.sls` (enabled on host `telfir`)

## Usage

### music-tui TUI

```
music-tui                      interactive mode selector (fzf picker)
music-tui similar              find similar tracks for current or selected track
music-tui classify [file]      run Essentia highlevel classification on a file
music-tui profile              show collection statistics (file count, size, index info, now playing)
music-tui interactive          browse music files with similarity previews and drill-down
```

Mode aliases: `s`/`similar`, `c`/`classify`, `p`/`stats`/`profile`, `i`/`b`/`browse`/`interactive`.

### CLI tools

```
music-index [--out DIR] [-j N] [-n N] [-v|-vv] [--quiet] [MUSIC_DIR]
  Scan MUSIC_DIR (default: $MUSIC_DIR or ~/music), extract Essentia features,
  cache vectors by content hash, and build Annoy index under --out (default: ~/.cache/music-index).

music-similar [--index DIR] [-k N] [AUDIO]
  Query the index for the top-N nearest neighbors (default: 15).
  If AUDIO is omitted, reads the current track URL via playerctl.

music-highlevel [options] [PATH ...]
  Run Essentia highlevel classifiers. Options:
    --top N              top probabilities per taxonomy to display (default: 3)
    --taxonomies T1 T2   specific taxonomies (default: genre, moods, danceability, tonal_atonal)
    --json               emit JSON per track
  If PATH is omitted, defaults to the current playerctl track.
```

## Systemd Timer

- **Service:** `music-index.service` (type=oneshot, runs `music-index`)
- **Timer:** `music-index.timer` (weekly, persistent, 2h randomized delay)

```ini
[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=2h
```

Enable and start:

```
systemctl --user enable --now music-index.timer
```

Check status:

```
systemctl --user list-timers
systemctl --user status music-index.service
```

## Troubleshooting

| Symptom | Check |
|---|---|
| Index not found / "run music-index first" | Run `music-index ~/music` to build the index |
| Playerctl not working | Ensure MPD or Spotify is running and detectable via MPRIS |
| Essentia extractor fails | Run `just validate` and check `systemctl --user status music-index.service` |
| Binary not found | Verify `~/.local/bin/` is in `$PATH` and has `music-index`, `music-similar`, `music-highlevel` |
| `python-annoy` import error | `music-index` checks on startup; re-run Salt state or `paru -S python-annoy` |
| Slow first index build | Expected — Essentia extraction is CPU-intensive. Subsequent runs reuse cached feature vectors by content hash. Use `-j N` to control parallelism. |
