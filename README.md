<h1 align="center">Tisa Dynamic Island</h1>

<p align="center">Turns the MacBook notch into a small Dynamic Island: music controls, calendar, file shelf, clipboard history, a Photo Booth and a Khmer postage-stamp booth.</p>

Tisa Dynamic Island is a personal fork of [Boring Notch](https://github.com/TheBoredTeam/boring.notch) by TheBoredTeam, with extra features and a Liquid Glass look.

## Install and use on Mac

**macOS 15 Sequoia or later is required.** There is currently no ready-to-install Mac
`.dmg` or `.zip` in this repository's [GitHub Releases](https://github.com/kuntisa-dev/Tisa.notch/releases).
For now, Mac users need to build the app with Xcode. The Windows ZIP cannot run on macOS,
and GitHub's **Source code** downloads are not runnable apps.

### Build and install

1. Install **Xcode 26 or later** from the Mac App Store or Apple Developer downloads.
   Your Mac must run a macOS version supported by that Xcode release. Open Xcode once
   to finish setup, then add your Apple ID in **Xcode → Settings → Accounts**.
2. Download this repository using **Code → Download ZIP** and extract it, or run:

   ```bash
   git clone https://github.com/kuntisa-dev/Tisa.notch.git
   cd Tisa.notch
   ```

3. Open **TisaDynamicIsland.xcodeproj** and wait for Swift packages to finish resolving.
4. Select the project in Xcode's sidebar. Under **Signing & Capabilities**, choose your
   own **Team** for **TisaDynamicIsland**, **TisaDynamicIslandXPCHelper** and **TisaFanHelper**.
   Enable **Automatically manage signing** where available. If Xcode reports a bundle
   identifier conflict, use your own unique identifiers for your local build.
5. Choose the **TisaDynamicIsland** scheme and **My Mac** as the destination.
   Quit Boring Notch or any older copy of Tisa Dynamic Island, then press **⌘R** to build
   and try the app.
6. To keep an installed copy, stop the Xcode run and choose **Product → Build**.
   Find **Tisa Dynamic Island.app** under Xcode's **Products** group, right-click it →
   **Show in Finder**, and copy it to **Applications**. Open it from Applications.
   Keep only one running copy.

For a signed Release build, including support for the optional fan-control helper,
create an **Apple Development** certificate in **Xcode → Settings → Accounts →
Manage Certificates**, then run this from the repository folder:

```bash
./Scripts/build-release.sh
```

Quit the running app, then copy `build/Build/Products/Release/Tisa Dynamic Island.app`
to **Applications** and open it. Fan-speed changes require a separate one-time setup
in **Tisa Fan Studio → Settings → Fan Control**; follow the install command shown there.
Debug builds from ⌘R cannot control fan speeds.

### First launch and everyday use

1. Complete the welcome screen. The app lives at the top of your display and in the
   menu bar; it does not need a Dock window to stay running.
2. Hover over the notch to open it, or press **⌘⇧I** (Command + Shift + I).
   Use the tabs to switch between music, Calendar, Shelf, Clipboard and Photo Booth.
3. Click the **sparkle icon in the menu bar → Settings**. In **General**, choose your
   preferred display and enable **Launch at login** if you want it to start automatically.
   Use **Home & Tabs** to choose the tabs and Home tiles, and **Themes** to change its look.
4. Play music in your usual music app to use playback controls. Drag files onto the
   notch to use the Shelf. In **Calendar**, select a day to add notes or routines.
5. To close the app, choose **Quit** from its menu bar icon.

Default shortcuts (customize them in **Settings → Shortcuts**):

| Action | Shortcut |
| --- | --- |
| Open or close the notch | Command + Shift + I |
| Clipboard history | Control + Option + V |
| Mute or unmute the microphone | Control + Option + M |
| Photo Booth | Control + Option + P |
| Khmer stamp booth | Control + Option + K |

### Permissions and troubleshooting

Allow permissions when you use the corresponding feature: **Camera** for the mirror
and Photo Booth, **Calendars/Reminders** for Apple events and reminders, **Notifications**
for alerts, **Automation** for music-app control, and folder access for downloads or
saved photos. If macOS asks for **Microphone** access, it supports the microphone feature.
The audio-reactive visualizer also needs **Screen & System Audio Recording** access;
restart the app after granting it. Review these in **System Settings → Privacy & Security**
or **System Settings → Notifications**.

- **Nothing appears:** quit other notch apps, open Tisa Dynamic Island again, then
  check **Settings → General → Preferred display** and try **⌘⇧I**.
- **A feature is missing:** enable it in Settings and check **Home & Tabs** to show its tab.
- **Signing fails:** check that all three targets use your own team and that Xcode has
  a valid Apple Development certificate. Retry after Swift packages finish resolving.
- **macOS blocks a downloaded copy:** only if you trust its source, try opening it,
  then use **System Settings → Privacy & Security → Open Anyway** if offered.
  If a trusted copy is still blocked by quarantine, run:

  ```bash
  xattr -dr com.apple.quarantine "/Applications/Tisa Dynamic Island.app"
  ```

To update this Mac build, download or pull the latest source, rebuild, quit the old app,
and replace the copy in Applications. The current **Check for Updates** menu item points
to upstream Boring Notch, so use this repository for Tisa updates. To uninstall, quit the
app and move **Tisa Dynamic Island.app** from Applications to the Trash.

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

- macOS 15 Sequoia or later to run the Mac app
- Xcode 26 or later and a macOS version supported by that Xcode release to build
- See [Install and use on Mac](#install-and-use-on-mac) above for the complete steps.

## License and credits

Tisa Dynamic Island is licensed under the GNU General Public License v3.0, the same as Boring Notch. See [LICENSE](LICENSE) and [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).

Based on [Boring Notch](https://github.com/TheBoredTeam/boring.notch) by TheBoredTeam and its contributors. Icon by [@maxtron95](https://github.com/maxtron95). Media control uses [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter), and the shelf started from [NotchDrop](https://github.com/Lakr233/NotchDrop).

## GitHub automation

Builds run with Xcode 26. Code scanning and updater hosting are optional: configure the corresponding GitHub service, then set the repository Actions variable `ENABLE_CODEQL` or `ENABLE_PAGES` to `true` to enable its workflow. Code scanning and Pages availability depend on the repository plan and visibility.
