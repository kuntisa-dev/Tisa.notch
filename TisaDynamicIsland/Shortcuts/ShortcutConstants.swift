//
//  Constants.swift
//  TisaDynamicIsland
//
//  Created by Richard Kunkli on 16/08/2024.
//

import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    // Control-Option defaults avoid clashing with common app shortcuts (⇧⌘C is "Inspect" in Chrome and "Computer" in Finder).
    static let clipboardHistoryPanel = Self("clipboardHistoryPanel", default: .init(.v, modifiers: [.control, .option]))
    static let toggleMicrophone = Self("toggleMicrophone", default: .init(.m, modifiers: [.control, .option]))
    static let openPhotoBooth = Self("openPhotoBooth", default: .init(.p, modifiers: [.control, .option]))
    static let openPhotoBoothMode = Self("openPhotoBoothMode", default: .init(.k, modifiers: [.control, .option]))
    static let decreaseBacklight = Self("decreaseBacklight", default: .init(.f1, modifiers: [.command]))
    static let increaseBacklight = Self("increaseBacklight", default: .init(.f2, modifiers: [.command]))
    static let toggleSneakPeek = Self("toggleSneakPeek", default: .init(.h, modifiers: [.command, .shift]))
    static let toggleNotchOpen = Self("toggleNotchOpen", default: .init(.i, modifiers: [.command, .shift]))
}
