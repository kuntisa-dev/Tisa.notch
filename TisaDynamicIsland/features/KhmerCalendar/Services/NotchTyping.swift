//
//  NotchTyping.swift
//  TisaDynamicIsland
//
//  Lets a text field inside the notch take the keyboard. The notch window normally refuses
//  to become the key window, so hovering it never pulls typing away from the app in front.
//  While a note is being written it accepts the keyboard, and gives it back afterwards.
//

import AppKit

@MainActor
enum NotchTyping {
    /// Read by the notch window's `canBecomeKey`.
    private(set) static var isActive = false
    private static weak var window: NSWindow?
    private static var closeObserver: NSObjectProtocol?

    static func begin() {
        guard !isActive else { return }
        isActive = true
        SharingStateManager.shared.beginInteraction()

        let mouse = NSEvent.mouseLocation
        let notches = NSApp.windows.filter { $0 is TisaDynamicIslandSkyLightWindow }
        window = notches.first { $0.frame.contains(mouse) } ?? notches.first
        // The notch window is replaced when screens change; the editor inside it may then
        // go away without onDisappear, which would leave the notch unable to close.
        if let window {
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { _ in
                MainActor.assumeIsolated { end() }
            }
        }
        window?.makeKey()
    }

    static func end() {
        guard isActive else { return }
        isActive = false
        SharingStateManager.shared.endInteraction()
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        window?.resignKey()
        window = nil
    }
}
