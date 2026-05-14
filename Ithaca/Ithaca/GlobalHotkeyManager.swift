//
//  GlobalHotkeyManager.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/28/26.
//

import Foundation
import Carbon

final class GlobalHotkeyManager {
    private let onTrigger: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var isHandlerInstalled = false
    private let hotKeyID = EventHotKeyID(signature: OSType(UInt32(0x49544843)), id: 1)

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        installHandler()
    }

    deinit {
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    func update(hotkey: Hotkey?) -> HotkeyRegistrationStatus {
        unregister()
        guard let hotkey else { return .disabled }
        guard isHandlerInstalled else { return .unavailable }
        return register(hotkey: hotkey)
    }

    private func installHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.onTrigger()
            }
            return noErr
        }
        isHandlerInstalled = InstallEventHandler(
            GetEventDispatcherTarget(),
            handler,
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &handlerRef
        ) == noErr
    }

    private func register(hotkey: Hotkey) -> HotkeyRegistrationStatus {
        var registeredHotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &registeredHotKey
        )
        guard status == noErr, let registeredHotKey else { return .unavailable }
        hotKeyRef = registeredHotKey
        return .registered
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
