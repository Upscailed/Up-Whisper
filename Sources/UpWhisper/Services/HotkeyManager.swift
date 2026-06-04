import AppKit
import ApplicationServices

class HotkeyManager {
    var onTrigger: (() -> Void)?
    private var monitor: Any?

    func register() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            print("[Hotkey] Accessibility niet toegestaan — systeemdialoog geopend")
            return
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
            if flags == [.control, .option] {
                self?.onTrigger?()
            }
        }
        print("[Hotkey] \(monitor != nil ? "Geregistreerd: ⌃⌥" : "Registratie mislukt")")
    }

    func unregister() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
