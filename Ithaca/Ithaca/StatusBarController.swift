//
//  StatusBarController.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/26/26.
//

import SwiftUI
import AppKit
import Combine

final class PopoverState: ObservableObject {
    @Published var isShown: Bool = false
}

final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let popoverState: PopoverState

    init(store: RepoStore, popoverState: PopoverState, hotkeyStore: HotkeyStore) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.popoverState = popoverState
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: RootView(
                store: store,
                popoverState: popoverState,
                hotkeyStore: hotkeyStore,
                onRequestClose: { [weak self] in self?.closePopover() }
            )
        )

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "sailboat", accessibilityDescription: "Ithaca")
                ?? NSImage(systemSymbolName: "location.north.circle", accessibilityDescription: "Ithaca")
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func togglePopoverFromHotkey() {
        togglePopover()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popoverState.isShown = true
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
        popoverState.isShown = false
    }

    func popoverDidClose(_ notification: Notification) {
        popoverState.isShown = false
    }
}
