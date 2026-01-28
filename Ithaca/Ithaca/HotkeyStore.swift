//
//  HotkeyStore.swift
//  Ithaca
//
//  Created by Armando Valencia on 1/28/26.
//

import Foundation
import Carbon
import Combine

struct Hotkey: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    var displayString: String {
        modifiersString + keyLabel
    }

    private var modifiersString: String {
        var result = ""
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        return result
    }
}

@MainActor
final class HotkeyStore: ObservableObject {
    @Published private(set) var hotkey: Hotkey?

    private let hotkeyKey = "globalHotkey"
    private let defaultHotkey = Hotkey(
        keyCode: UInt32(kVK_ANSI_I),
        modifiers: UInt32(cmdKey | optionKey | controlKey),
        keyLabel: "I"
    )
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        load()
        if hotkey == nil {
            setHotkey(defaultHotkey)
        }
    }

    func setHotkey(_ hotkey: Hotkey?) {
        self.hotkey = hotkey
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: hotkeyKey),
              let hotkey = try? decoder.decode(Hotkey.self, from: data) else {
            return
        }
        self.hotkey = hotkey
    }

    private func save() {
        guard let hotkey else {
            UserDefaults.standard.removeObject(forKey: hotkeyKey)
            return
        }
        if let data = try? encoder.encode(hotkey) {
            UserDefaults.standard.set(data, forKey: hotkeyKey)
        }
    }

 
}
