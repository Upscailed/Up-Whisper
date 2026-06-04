import AppKit
import ApplicationServices

class HotkeyManager {
    /// Combo werd actief (toetsen ingedrukt).
    var onPress: (() -> Void)?
    /// Combo werd losgelaten.
    var onRelease: (() -> Void)?

    private var monitor: Any?
    private var comboActive = false

    /// Beschikbare modifier-combinaties voor de instellingen.
    static let options: [(id: String, label: String)] = [
        ("control_option", "⌃⌥  Control + Option"),
        ("control_shift", "⌃⇧  Control + Shift"),
        ("option_shift", "⌥⇧  Option + Shift"),
        ("control_option_shift", "⌃⌥⇧  Control + Option + Shift")
    ]

    static func flags(for id: String) -> NSEvent.ModifierFlags {
        switch id {
        case "control_shift": return [.control, .shift]
        case "option_shift": return [.option, .shift]
        case "control_option_shift": return [.control, .option, .shift]
        default: return [.control, .option]
        }
    }

    /// Leest de actueel gekozen combo uit UserDefaults (live aanpasbaar).
    private var requiredFlags: NSEvent.ModifierFlags {
        let id = UserDefaults.standard.string(forKey: "hotkeyModifiers") ?? "control_option"
        return Self.flags(for: id)
    }

    func register() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("[Hotkey] Accessibility niet toegestaan — systeemdialoog geopend")
            return
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
            let isActive = (flags == self.requiredFlags)
            if isActive && !self.comboActive {
                self.comboActive = true
                self.onPress?()
            } else if !isActive && self.comboActive {
                self.comboActive = false
                self.onRelease?()
            }
        }
        print("[Hotkey] \(monitor != nil ? "Geregistreerd" : "Registratie mislukt")")
    }

    func unregister() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        comboActive = false
    }
}
