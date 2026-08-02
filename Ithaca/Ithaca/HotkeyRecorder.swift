//
//  HotkeyRecorder.swift
//  Ithaca
//
//  Created by Armando Valencia on 8/2/26.
//

import SwiftUI
import AppKit
import Carbon

struct HotkeyRecorder: View {
    @ObservedObject var hotkeyStore: HotkeyStore
    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(hotkeyStore.hotkey?.displayString ?? "Off")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.12))
                    )
                Text(hotkeyStore.registrationStatus.label)
                    .font(.caption)
                    .foregroundStyle(hotkeyStore.registrationStatus == .unavailable ? Color.red : Color.secondary)
                Spacer()
                Button(isRecording ? "Cancel" : "Record Shortcut") {
                    isRecording ? stopRecording() : startRecording()
                }
            }

            if isRecording {
                Text("Press a key with at least one modifier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if hotkeyStore.registrationStatus == .unavailable {
                Text("This shortcut is unavailable. Choose another shortcut.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                Button("Disable") {
                    hotkeyStore.setHotkey(nil)
                }
                .buttonStyle(.link)
                .disabled(hotkeyStore.hotkey == nil)
                Button("Restore Default") {
                    hotkeyStore.restoreDefaultHotkey()
                }
                .buttonStyle(.link)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        message = nil
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !event.isARepeat else { return nil }
            guard let hotkey = Hotkey(event: event) else {
                message = "Use Command, Option, Control, or Shift with a key."
                return nil
            }
            hotkeyStore.setHotkey(hotkey)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        isRecording = false
    }
}

private extension Hotkey {
    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty,
              let keyLabel = event.charactersIgnoringModifiers?.uppercased(),
              !keyLabel.isEmpty else {
            return nil
        }

        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }

        self.init(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers, keyLabel: keyLabel)
    }
}
