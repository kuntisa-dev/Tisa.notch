# Full feature parity tracker

Goal: reproduce the Mac experience on Windows 11, using Windows system services.
User-approved platform policy: omit unavailable controls from the Windows interface
and explain differences in Settings. Mark only Apple-specific integrations as macOS-only;
features awaiting a Windows port are not yet available, and PC fan support depends on hardware.
`Implemented` means source exists, not that it has passed real-device acceptance.
Features marked pending are not exposed as working buttons or simulated data.

| Mac functionality | Windows implementation / approach | Current status |
| --- | --- | --- |
| Floating island, hover, keyboard toggle | WPF transparent window; Win32 hotkeys and tray | Implemented with compact/expanded layouts, pinning and second-instance activation; real-device QA pending |
| Liquid Glass and themes | Windows composition / custom glass approximation | Basic dark surface only; advanced appearance pending |
| Multi-monitor, full-screen hide, animation, Reduce Motion | Display configuration and accessibility settings | Display choice, DPI placement, disconnect fallback and full-screen hiding implemented; native device QA and animation/accessibility refinements pending |
| Editable tabs, Home widgets, sizes, stacks, undo | Windows layout models and native views | Fixed Home plus five pages; editor pending |
| Now playing, play/pause/skip | Windows global media sessions | Implemented; provider QA pending |
| Album art, seeking, volume, visualizer | Session timeline/artwork + WASAPI loopback | Album art and seeking implemented when supported by the player; volume/visualizer pending |
| Microphone mute and shortcut | Core Audio capture endpoint control | Pending |
| Volume, brightness, keyboard-backlight HUD | Core Audio, display APIs, vendor-specific backlight | Pending; keyboard backlight is hardware dependent |
| Clipboard text/images, memory-only history, clear | Win32 clipboard listener + WPF bitmap/text | Implemented; privacy formats and contention need device QA |
| Downloads and completion notices | Known Downloads folder + browser partial files | Bytes/count implemented; completion notices pending |
| File shelf, drag in/out, file actions | Windows file-drop data and shell open | Implemented; sharing and persistence pending |
| AirDrop | Windows sharing UI / Nearby Sharing | Pending replacement; AirDrop protocol is not a Windows feature |
| Battery and charging notifications | Windows power APIs | Battery label implemented; charging alerts pending |
| Recent apps and app launcher | Foreground-window tracking and shell integration | Pending |
| Calendar, reminders, next event, meeting join | Provider adapters with explicit account access | Pending; no reuse of Apple EventKit credentials |
| Khmer lunar calendar and holidays | Port pure KhmerCalendarKit calculations; preserve MIT attribution | Pending; validate against existing conversion fixtures |
| Day notes, routine editor, backups, reminders, typing effects | Portable domain models, local storage, Windows notifications | Pending; validate backup import/export compatibility |
| AI Usage dashboard, accounts, limits, reset timers, history | Port AIUsageKit providers and Windows credential discovery | Pending; preserve upstream MIT notices; no credential upload |
| Camera mirror and photos, countdown, photo library | Windows camera capture | Pending |
| 19 photo effects | GPU/image processing equivalents | Pending |
| All booth formats, filters and poster artwork | Reuse licensed layout/assets; new renderer | Pending |
| Segmented backgrounds, blur and studio scenes | Windows-compatible person segmentation inference | Pending; select model and verify its license |
| Fan Studio sensors, curves, profiles, diagnostics | Separate hardware provider and privileged helper | Pending; Apple SMC cannot control PC fans; support must be validated per hardware |
| Settings, launch at login, shortcuts | Local JSON, Windows startup registration, Win32 hotkeys | Basic settings/toggle implemented; remaining settings pending |
| Installer, signing, updates | Windows packaging, Authenticode, update channel | Portable unsigned x64 development build only |
| Accessibility and localization | Keyboard navigation, UI Automation, translated resources | Initial keyboard support; audit and translations pending |

## Work order

1. Validate the native shell, tray lifecycle, hotkeys, media, clipboard and downloads
   on Windows 11; test DPI, disconnected screens, screen lock and Explorer restart.
2. Port Khmer calendar and routines against the existing Swift fixtures, then calendar
   adapters, notifications, battery alerts, audio controls and app switching.
3. Port Home customization and AI Usage provider by provider, with Windows credential
   isolation and failure states verified for each provider.
4. Add camera, photo processing, templates and segmentation with image-output comparisons.
5. Add hardware telemetry and fan control only for tested PC hardware, then package,
   sign, test upgrades/uninstall, and publish a Windows release.

## Acceptance before full parity is claimed

Every feature in the Mac inventory must either pass equivalent Windows behavior
checks or have an explicitly agreed Windows replacement. No fake sensor values,
download percentages or AI limits. Test Windows 11 on a laptop and desktop; media
providers, redirected Downloads, clipboard exclusion formats, camera permission
denial, absent battery, mixed DPI, hardware disconnection, resume and logout must
be handled. Signing, updates and fan-helper privileges need separate release QA.
