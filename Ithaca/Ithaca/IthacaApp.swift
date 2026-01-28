//
//  IthacaApp.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/26/26.
//

import SwiftUI
import AppKit
import Combine

@main
struct IthacaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let store = RepoStore()
    private let popoverState = PopoverState()
    private let hotkeyStore = HotkeyStore()
    private var hotkeyManager: GlobalHotkeyManager?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.loadCacheAndRescan()
        statusBarController = StatusBarController(store: store, popoverState: popoverState, hotkeyStore: hotkeyStore)
        hotkeyManager = GlobalHotkeyManager { [weak self] in
            self?.statusBarController?.togglePopoverFromHotkey()
        }
        hotkeyStore.$hotkey
            .sink { [weak self] hotkey in
                self?.hotkeyManager?.update(hotkey: hotkey)
            }
            .store(in: &cancellables)
    }
}
