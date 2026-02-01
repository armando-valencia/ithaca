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
    @Published var focusRequestID: UUID = UUID()

    func requestFocus() {
        focusRequestID = UUID()
    }
}

final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let popoverState: PopoverState
    private var panel: NSPanel?
    private let store: RepoStore
    private let hotkeyStore: HotkeyStore

    init(store: RepoStore, popoverState: PopoverState, hotkeyStore: HotkeyStore) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.popoverState = popoverState
        self.store = store
        self.hotkeyStore = hotkeyStore
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.contentViewController = makeHostingController()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "sailboat", accessibilityDescription: "Ithaca")
                ?? NSImage(systemSymbolName: "location.north.circle", accessibilityDescription: "Ithaca")
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    @objc private func togglePopover() {
        if popover.isShown || panel?.isVisible == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    func togglePopoverFromHotkey() {
        if panel?.isVisible == true {
            closePopover()
        } else {
            showPanel(for: activeScreen())
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        if shouldShowPanel(for: button) {
            showPanel(for: button.window?.screen)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popoverState.isShown = true
            popoverState.requestFocus()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        panel?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        popoverState.isShown = false
    }

    func popoverDidClose(_ notification: Notification) {
        popoverState.isShown = false
    }

    private func makeHostingController() -> NSHostingController<RootView> {
        NSHostingController(
            rootView: RootView(
                store: store,
                popoverState: popoverState,
                hotkeyStore: hotkeyStore,
                onRequestClose: { [weak self] in self?.closePopover() }
            )
        )
    }

    private func shouldShowPanel(for button: NSStatusBarButton) -> Bool {
        if isAnyAppFullscreen() {
            return true
        }
        guard let screen = button.window?.screen ?? NSScreen.main else { return false }
        return isMenuBarHidden(on: screen)
    }

    private func isMenuBarHidden(on screen: NSScreen) -> Bool {
        let visibleMaxY = screen.visibleFrame.maxY
        let frameMaxY = screen.frame.maxY
        return abs(visibleMaxY - frameMaxY) < 1.0
    }

    private func isAnyAppFullscreen() -> Bool {
        if let keyWindow = NSApp.keyWindow, keyWindow.styleMask.contains(.fullScreen) {
            return true
        }
        return false
    }

    private func activeScreen() -> NSScreen? {
        if let keyWindow = NSApp.keyWindow {
            return keyWindow.screen
        }
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
    }

    private func showPanel(for screen: NSScreen?) {
        let screen = screen ?? NSScreen.main
        guard let screen else { return }

        let contentSize = NSSize(width: 420, height: 520)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        let contentRect = NSRect(origin: .zero, size: contentSize)
        let frameRect = NSWindow.frameRect(forContentRect: contentRect, styleMask: styleMask)
        let origin = NSPoint(
            x: screen.visibleFrame.midX - frameRect.width / 2,
            y: screen.visibleFrame.midY - frameRect.height / 2
        )
        var frame = NSRect(origin: origin, size: frameRect.size)
        frame.origin.x = max(screen.visibleFrame.minX, min(frame.origin.x, screen.visibleFrame.maxX - frame.width))
        frame.origin.y = max(screen.visibleFrame.minY, min(frame.origin.y, screen.visibleFrame.maxY - frame.height))

        if panel == nil {
            let panel = IthacaPanel(
                contentRect: frame,
                styleMask: styleMask,
                backing: .buffered,
                defer: false
            )
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = false
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.becomesKeyOnlyIfNeeded = false
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.isReleasedWhenClosed = false
            panel.contentViewController = makeHostingController()
            self.panel = panel
        }

        NSApp.setActivationPolicy(.regular)
        panel?.setFrame(frame, display: true)
        NSApp.unhide(nil)
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        popoverState.isShown = true
        popoverState.requestFocus()
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel else { return }
            panel.makeKeyAndOrderFront(nil)
            panel.makeMain()
            panel.makeFirstResponder(panel.contentView)
            NSApp.activate(ignoringOtherApps: true)
            self.popoverState.requestFocus()
        }
    }
}
