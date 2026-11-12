# Windows 0.2.0

## Interface

- Compact 420 px island and 800 px expanded workspace, bounded by the primary screen's work area.
- Selected tabs, keyboard focus outlines, Ctrl + 1–5 shortcuts, Pin/Unpin and Hide to tray.
- Album artwork, a playback timeline and seeking when supported by the active media app.
- Clipboard opt-in from the empty state, image previews, useful empty states and inactive Clear buttons.
- Shelf filenames with full paths, Enter to open and Delete to remove a reference.
- Scrollable settings with Windows power settings and clear hardware/platform support notes.

## Reliability

- Sequence-based clipboard ownership fixes accidentally skipping someone else's next copy.
- Clipboard images share a 32 MB memory budget, in addition to per-image and entry limits.
- Downloads scan off the UI thread. Renaming/deleting one browser partial file no longer aborts
  the rest of the scan; missing folders clear stale entries and recover automatically.
- Unchanged downloads preserve list items instead of replacing the entire list every poll.
- Media requests have timeouts. Buttons follow the player's individual advertised capabilities,
  and repeated commands are prevented while a command is pending.
- Invalid battery readings no longer appear as percentages; desktops are labeled explicitly.
- Launching again restores the existing window instead of silently exiting.
- A shortcut conflict remains explained in Settings, even after switching tabs.

## Validation and limits

Portable regression checks exercise real download files, battery values and clipboard sequence
handling. Windows smoke checks render every page and a narrow Home layout, and exercise
folder recovery, stable download items, selection, pinning and collapse.

Real-device testing is still required for media-provider quirks, clipboard contention,
mixed-DPI setups, suspend/resume and tray recovery after Explorer restarts. This release
does not add camera, calendar, AI usage or PC fan control.
