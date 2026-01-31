//
//  HotkeyManager.swift
//  Halftone
//
//  Global hotkey registration using Carbon API
//

import Foundation
import Carbon

class HotkeyManager {

    private var hotkeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?

    // Store reference for the C callback
    private static var instance: HotkeyManager?

    init(handler: @escaping () -> Void) {
        self.handler = handler
        HotkeyManager.instance = self
        registerHotkey()
    }

    deinit {
        unregisterHotkey()
        HotkeyManager.instance = nil
    }

    // MARK: - Hotkey Registration

    private func registerHotkey() {
        // Cmd+Shift+H
        // Key code for 'H' is 4
        let keyCode: UInt32 = 4
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x48544E45) // "HTNE" for Halftone
        hotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        // Install event handler
        var eventHandler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                HotkeyManager.instance?.handler?()
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard status == noErr else {
            print("Failed to install event handler: \(status)")
            return
        }

        // Register the hotkey
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if registerStatus != noErr {
            print("Failed to register hotkey: \(registerStatus)")
        } else {
            print("Registered global hotkey: Cmd+Shift+H")
        }
    }

    private func unregisterHotkey() {
        if let hotkey = hotkeyRef {
            UnregisterEventHotKey(hotkey)
            hotkeyRef = nil
        }
    }
}
