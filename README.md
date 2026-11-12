<h1 align="center">Tisa Dynamic Island</h1>

<p align="center">Turns the MacBook notch into a small Dynamic Island: music controls, calendar, file shelf, clipboard history, a Photo Booth and a Khmer postage-stamp booth.</p>

Tisa Dynamic Island is a personal fork of [Boring Notch](https://github.com/TheBoredTeam/boring.notch) by TheBoredTeam, with extra features and a Liquid Glass look.

## Download and install on Windows

**Windows 11 x64 desktops and laptops:** [Download Windows v0.3.2](https://github.com/kuntisa-dev/Tisa.notch/releases/tag/windows-v0.3.2).
This is an early development build. Native Windows acceptance testing is still pending,
and it does not yet include every Mac feature.

1. Open the release link and expand **Assets**.
2. Download **TisaDynamicIsland-windows-x64-0.3.2.zip**. Choose the Windows ZIP;
   the automatically generated **Source code** downloads contain source, not the runnable app.
3. Right-click the ZIP in File Explorer → **Extract All**. Keep the entire extracted folder.
4. Open the extracted folder and double-click **TisaDynamicIsland.exe**.
   No Xcode, Visual Studio, .NET SDK or separate .NET runtime installation is required.
5. The island appears near the top of your display. Press **Ctrl + Alt + Space** to open it,
   or use its tray icon. Choose your monitor and layout in **Settings → Desktop & displays**.

To test this development build, quit the app from its tray menu, then double-click
**Test-Windows.cmd** in the same extracted folder. It creates local results on your Desktop
and uploads nothing. See [the full Windows guide](Windows/README.md) for features, updates,
uninstallation and the manual test checklist.

This repository and its release downloads are public. No collaborator invitation is required.

## Mac version

The existing Mac app and its Xcode build instructions are below. The Windows ZIP runs only on Windows.

## Features

From Boring Notch:

- Music controls with album art and a visualizer (Apple Music, Spotify, YouTube Music and more)
- Calendar and reminders
- File shelf with AirDrop
- Volume, brightness and keyboard-backlight HUD that replaces the macOS one
- Battery status and a camera mirror

Added in Tisa Dynamic Island (details in [CUSTOM_FEATURES.md](CUSTOM_FEATURES.md)):

- Microphone mute shortcut (⌃⌥M)
- Clipboard history tab (⌃⌥V)
- Download progress for Safari, Chrome-based browsers and Firefox
- Photo Booth tab with 19 live effects (⌃⌥P)
- Khmer stamp booth that turns 3 or 4 photos into a Khmer Heritage postage stamp (⌃⌥K)
- Liquid Glass design for the open notch
- Visualizer that follows the music

## Requirements

**Windows version:** a native Windows 11 port is in early development. See
[Windows build instructions and current status](Windows/README.md). It does not yet match all Mac features.

- macOS 14 Sonoma or later to run
- macOS 15.6 or later and Xcode 26 or later to build

## Build from source

1. Open `TisaDynamicIsland.xcodeproj` in Xcode and wait for Swift packages to resolve.
2. In Signing & Capabilities, set your Apple ID as Team for the **TisaDynamicIsland** and **TisaDynamicIslandXPCHelper** targets.
3. Quit Boring Notch if it's running, then press ⌘R.

The app is unsigned for distribution, so a copy moved to another Mac needs its quarantine flag removed once:

```bash
xattr -dr com.apple.quarantine "/Applications/Tisa Dynamic Island.app"
```

## License and credits

Tisa Dynamic Island is licensed under the GNU General Public License v3.0, the same as Boring Notch. See [LICENSE](LICENSE) and [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).

Based on [Boring Notch](https://github.com/TheBoredTeam/boring.notch) by TheBoredTeam and its contributors. Icon by [@maxtron95](https://github.com/maxtron95). Media control uses [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), and the shelf started from [NotchDrop](https://github.com/Lakr233/NotchDrop).

## GitHub automation

Builds run with Xcode 26. Code scanning and updater hosting are optional: configure the corresponding GitHub service, then set the repository Actions variable `ENABLE_CODEQL` or `ENABLE_PAGES` to `true` to enable its workflow. Code scanning and Pages availability depend on the repository plan and visibility.
