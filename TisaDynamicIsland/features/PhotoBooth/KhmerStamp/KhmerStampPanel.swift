//
//  KhmerStampPanel.swift
//  TisaDynamicIsland
//
//  Opens the Khmer stamp booth in its own panel just below the notch.
//  Merged from Tisa Notch Studio (github.com/Tisa7777/tisa-notch-studio).
//

import AppKit
import SwiftUI

@MainActor
final class KhmerStampPanelController: NSObject, NSWindowDelegate {
    static let shared = KhmerStampPanelController()

    private let booth = KhmerStampBooth()
    private var panel: KhmerStampWindow?

    var isVisible: Bool { panel?.isVisible == true }

    func toggle() {
        if isVisible {
            close()
        } else {
            show()
        }
    }

    func show() {
        // Only one camera session at a time: let go of the notch's mirror and Photo Booth tab.
        WebcamManager.shared.stopSession()
        PhotoBoothCamera.shared.stop()

        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let panel = panel ?? makePanel()
        self.panel = panel
        place(panel, on: screen)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        booth.opened()
    }

    func close() {
        guard !booth.isSaving else { return }
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        booth.closed()
    }

    private func makePanel() -> KhmerStampWindow {
        let panel = KhmerStampWindow(
            contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false
        )
        panel.title = "Tisa Dynamic Island Khmer Photo Booth"
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        let view = KhmerStampBoothView(booth: booth, camera: booth.camera, close: { [weak self] in
            self?.close()
        }, save: { [weak self, weak panel] in
            guard let panel else { return }
            self?.booth.save(in: panel)
        })
        panel.contentViewController = NSHostingController(rootView: view)
        return panel
    }

    private func place(_ panel: NSPanel, on screen: NSScreen) {
        let area = screen.visibleFrame
        let top = min(area.maxY, screen.frame.maxY - screen.safeAreaInsets.top)
        let width = min(548, area.width - 16)
        let height = min(428, top - area.minY - 14)
        let originX = min(max(screen.frame.midX - width / 2, area.minX + 8), area.maxX - width - 8)
        panel.setFrame(NSRect(x: originX, y: top - height - 5, width: width, height: height), display: true)
    }
}

private final class KhmerStampWindow: NSPanel {
    override var canBecomeKey: Bool { true }
}
