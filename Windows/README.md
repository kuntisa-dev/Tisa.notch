# Tisa Dynamic Island for Windows

Native Windows companion to the Mac app, implemented in C# / WPF with .NET 10.
**Early development: this is not yet a feature-complete Windows release.** The target is
feature parity; see [PORTING.md](PORTING.md) for the full inventory and Windows replacements.
The Swift app remains in the repository and builds independently.

## Requirements

- Windows 11, x64. This first build does not include ARM64 binaries.
- For development: the .NET 10 SDK (or Visual Studio with .NET desktop development).
- The self-contained published build includes its runtime.

## Download a development build

On GitHub, open **Actions → Build Windows**, select a successful run on
`feature/windows-port`, then download **TisaDynamicIsland-windows-x64** from Artifacts.
Unzip the entire folder and run `TisaDynamicIsland.exe`. Access requires permission
to this private repository. These are unsigned development artifacts, not installers.

## Build on Windows

```powershell
dotnet run --project Windows/TisaDynamicIsland -c Release
```

Publish a portable app:

```powershell
dotnet publish Windows/TisaDynamicIsland -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o Windows/artifacts/windows-x64
```

## Current functionality

- Compact top-center island that expands into a larger workspace on hover or click.
  Use **Pin / Unpin** to control automatic collapse, or Escape to collapse immediately.
- Ctrl + Alt + Space toggles the island; the tray menu opens settings or quits.
- Ctrl + 1–5 switches pages, and tabs support keyboard focus and arrow navigation.
  Opening the app a second time brings the existing island back into view.
- Music title, artist, album art, playback timeline, seeking and previous/play-pause/next
  using Windows media sessions. Controls are enabled only when the player advertises
  support. Slow/unresponsive players time out and reconnect automatically.
  Only apps that publish a Windows media session can be controlled; artwork and seeking
  are optional and depend on the player.
- Clipboard text and images, explicitly enabled in Settings. The last 30 entries
  stay in memory with a 32 MB image budget and are cleared on lock or exit. Password-manager exclusion formats
  are honored when supplied; do not enable capture if your tools omit these markers.
- Chrome/Edge `.crdownload` and Firefox `.part` files in the Windows Downloads known
  folder, including redirected folders. Shows downloaded bytes, without inventing a percentage.
- File shelf: drop local files or folders, double-click or Enter to open, drag to other apps,
  and Delete to remove a reference. Duplicate paths are ignored without case sensitivity.
  The shelf stores in-memory references; clearing it does not delete files.
- Battery status and persistent preferences in `%LOCALAPPDATA%\TisaDynamicIsland\settings.json`.
- Settings includes **Hide to tray**, **Windows power settings**, and platform support notes.
  Windows power settings are not direct fan-speed controls.

The first layout anchors to the primary monitor's work area. Selecting a monitor,
full-screen behavior, richer animations and editable Home widgets are still pending.
Camera, microphones and fan hardware are not accessed by this build.

### Feature availability

Settings → **Feature availability on Windows** explains the platform differences.
Unavailable features are omitted from the tabs and switches. The notes distinguish
macOS-only integrations (AirDrop, Apple's Liquid Glass material and Apple SMC control)
from features not yet ported to Windows, such as Photo Booth, Khmer calendar/routines
and AI usage. PC fan controls remain hidden until a supported hardware integration
is available; PC fans are not described as a macOS-only feature.

## Validation

Download-file classification tests can run on macOS or Windows:

```powershell
dotnet run --project Windows/TisaDynamicIsland.Tests -c Release
```

The regression runner checks clipboard ownership/duplicate events, invalid and absent
battery states, and real download files that complete or disappear. Windows smoke
checks also cover folder recovery, unchanged list stability, selected tabs, pinning,
collapsing and scrollable support notes. Screenshots include a narrower 600 px layout.
The GitHub workflow builds and packages on a Windows runner. A macOS cross-build
checks compilation but cannot verify native Windows behavior; test on a real Windows
11 PC before treating any feature as ready to distribute.

WPF is configured with Microsoft's [Desktop SDK properties](https://learn.microsoft.com/en-us/dotnet/core/project-sdk/msbuild-props-desktop).
Media controls use [GlobalSystemMediaTransportControlsSessionManager](https://learn.microsoft.com/en-us/uwp/api/windows.media.control.globalsystemmediatransportcontrolssessionmanager).

## License

GPL-3.0, as in the root [LICENSE](../LICENSE). When porting third-party modules,
preserve their notices and licensing alongside the port.
