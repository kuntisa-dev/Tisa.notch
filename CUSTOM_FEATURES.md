# Tisa Notch: custom features (based on Boring Notch)

Based on Boring Notch 2.7.3 (build 271). Five features added; all new code is in `boringNotch/features/`.

## Build and run

1. Xcode 26 or later (the README asks for macOS 15.6+ to build; the app itself runs on macOS 14+).
2. Open `boringNotch.xcodeproj` and wait for Swift packages to resolve.
3. Signing & Capabilities: set your Apple ID as Team for the **boringNotch** and **BoringNotchXPCHelper** targets.
4. Quit the official Boring Notch and turn off its "Launch at login" (otherwise two notches run on top of each other), then press ⌘R.

This build was written without compiling on a Mac. If Xcode reports errors, copy them back to Claude.

## What's new

| Feature | How to use | Setting |
| --- | --- | --- |
| Microphone mute | ⌃⌥M mutes or unmutes the default input; the notch shows "Mic muted / unmuted" | Settings › Shortcuts |
| Clipboard history | ⌃⌥V opens the notch on a new Clipboard tab. Click a card to copy it again, then ⌘V | Settings › Clipboard |
| Download progress | Safari, Chrome-based browsers and Firefox downloads show in the closed notch (exact progress for Safari, a spinner for the others). Hover for name and size | Settings › Downloads |
| Photo Booth | New camera tab in the open notch (or ⌃⌥P). 19 live effects plus Normal. Color: Mono, Noir, Sepia, Chrome, Vintage, Fade, Glow, Pop Art, Comic, Thermal, X-Ray. Patterns: Pixelate, Halftone. Distortions: Mirror, Kaleidoscope, Light Tunnel, Bulge, Pinch, Twirl. Scroll the effect row sideways to see them all, 3/5/10 s countdown, flash and shutter sound. Click the preview or the shutter. Photos save to Pictures › Tisa Notch Photos; recent ones show beside the controls (click to open, right-click for Finder/Shelf, drag out) | Settings › Photo Booth |
| Khmer stamp booth | Merged from Tisa Notch Studio. Takes 3 or 4 photos, each with a 3/5/8 s countdown, and renders a Khmer Heritage postage stamp (cream paper, jade ink, Khmer text, postmark, perforated edge) to save as PNG. Opens in its own panel below the notch: menu bar › Khmer Photo Booth, ⌃⌥K, or the stamp button in the Photo Booth tab | Settings › Photo Booth › Khmer stamp booth |
| Liquid Glass look | Open notch redesign: frosted glass tab bar with a sliding accent pill, glass header buttons, glass calendar card, glass play button and hover states, a glowing progress bar with a knob, album-art color glow behind the player and a light rim around the notch. Uses macOS 26's Liquid Glass material when available, a drawn glass otherwise | Settings › Appearance › Tisa Notch look |
| Audio-reactive visualizer | Visualizer bars follow the music instead of random motion | Settings › Appearance › Music visualizer (off by default) |

## Permissions

- **Downloads folder**: new sandbox entitlement `com.apple.security.files.downloads.read-only`.
- **Microphone**: new entitlement `com.apple.security.device.audio-input` and `NSMicrophoneUsageDescription`, in case macOS asks before changing the mute state.
- **Pictures folder**: new entitlement `com.apple.security.assets.pictures.read-write`, so Photo Booth can save to ~/Pictures. The camera permission already existed for the mirror.
- **Screen & System Audio Recording**: only for the audio visualizer. macOS shows its recording indicator while it listens. Restart the app after granting it.

## Other changes

- Bundle ID is `com.kuntisa.tisanotch` (helper: `com.kuntisa.tisanotch.BoringNotchXPCHelper`), and the app is named "Tisa Notch", so it installs next to the official app instead of replacing it. It starts with fresh settings and asks for permissions again. The helper's XPC service name now follows the app's bundle ID automatically.
- Automatic update checks are off (`SUEnableAutomaticChecks = false`), so Sparkle won't replace this build with the official one. Don't use "Check for Updates" unless you want the official version back.
- The unused clipboard and microphone shortcut defaults (⇧⌘C, fn-F5) changed to ⌃⌥V and ⌃⌥M, because ⇧⌘C clashes with Chrome and Finder and fn-F5 can't be registered as a global hotkey.
- The microphone HUD shows even when "Replace system HUD" is off.
- Photo Booth runs the camera only while its tab is visible. Opened with ⌃⌥P it closes itself after 30 s unless the pointer is over the notch; a countdown keeps it open. It also stops the Home tab's mirror while in use.
- Tab icons now show their name on hover.

## Not yet tested on a Mac

- Muting uses the input device's mute switch, or input volume 0 if it has none. Some USB or Bluetooth mics may expose neither; you'll hear a beep then.
- Safari's download progress reads `DownloadEntryProgressBytesSoFar` / `DownloadEntryProgressTotalToLoad` from the `.download` bundle's Info.plist. If a Safari version stops writing those, progress falls back to a spinner.
- Photo Booth's shutter sound looks for macOS's `Shutter.aif` / `Grab.aif` system sounds and falls back to "Tink" if neither exists.
- The audio visualizer uses ScreenCaptureKit from the sandboxed app. If capture fails, the bars fall back to random motion and Xcode's console shows `SystemAudioAnalyzer: could not start capture`.

## Files

New: `features/KhmerStamp/` (KhmerStampBooth, KhmerStampCamera, PostageStamp, KhmerStampPanel), `features/TisaGlass.swift`, `features/MicrophoneManager.swift`, `ClipboardHistoryManager.swift`, `ClipboardHistoryView.swift`, `DownloadMonitor.swift`, `DownloadLiveActivity.swift`, `SystemAudioAnalyzer.swift`, `FeatureSettings.swift`, `PhotoBoothCamera.swift`, `PhotoBoothView.swift`.

Changed: `components/HoverButton.swift`, `components/Calendar/BoringCalendar.swift`, `components/Notch/NotchHomeView.swift`, `boringNotchApp.swift`, `ContentView.swift`, `BoringViewCoordinator.swift`, `components/Music/MusicVisualizer.swift`, `components/Settings/SettingsView.swift`, `components/Tabs/TabSelectionView.swift`, `components/Tabs/TabButton.swift`, `components/Notch/BoringHeader.swift`, `enums/generic.swift`, `models/Constants.swift`, `Shortcuts/ShortcutConstants.swift`, `Info.plist`, `boringNotch.entitlements`, `boringNotch.xcodeproj/project.pbxproj` (adds the synced `features` folder).

`features.patch` holds the same changes as a diff against the original source.
