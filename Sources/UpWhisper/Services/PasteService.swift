import AppKit
import CoreGraphics
import ApplicationServices

struct PasteService {
    static func paste(_ text: String, targetPID: pid_t = 0) {
        // When a specific target app is given (hotkey flow), bypass AX — Electron apps
        // like WhatsApp may return .success without actually inserting text.
        if targetPID > 0 {
            insertViaClipboard(text, targetPID: targetPID)
            return
        }
        if insertViaAccessibility(text) { return }
        insertViaClipboard(text, targetPID: targetPID)
    }

    // Injecteert tekst direct in het gefocuste AX-element — geen key-simulatie nodig.
    // Werkt voor alle standaard tekstvelden (NSTextField, NSTextView, browsers, Electron).
    private static func insertViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let copyError = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        print("[PasteService] AXCopyFocusedElement: \(copyError.rawValue) (\(axErrorDescription(copyError)))")
        guard copyError == .success, let focusedRef else { return false }

        let element = focusedRef as! AXUIElement
        let setError = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        print("[PasteService] AXSetSelectedText: \(setError.rawValue) (\(axErrorDescription(setError)))")
        return setError == .success
    }

    private static func axErrorDescription(_ err: AXError) -> String {
        switch err {
        case .success:             return "success"
        case .failure:             return "failure"
        case .illegalArgument:     return "illegalArgument"
        case .invalidUIElement:    return "invalidUIElement"
        case .invalidUIElementObserver: return "invalidUIElementObserver"
        case .cannotComplete:      return "cannotComplete"
        case .attributeUnsupported: return "attributeUnsupported"
        case .actionUnsupported:   return "actionUnsupported"
        case .notificationUnsupported: return "notificationUnsupported"
        case .notImplemented:      return "notImplemented"
        case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
        case .notificationNotRegistered: return "notificationNotRegistered"
        case .apiDisabled:         return "apiDisabled"
        case .noValue:             return "noValue"
        case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
        case .notEnoughPrecision:  return "notEnoughPrecision"
        @unknown default:          return "unknown(\(err.rawValue))"
        }
    }

    // Fallback: klembord + ⌘V gestuurd naar het opgeslagen PID.
    private static func insertViaClipboard(_ text: String, targetPID: pid_t) {
        let previous = NSPasteboard.general.string(forType: .string)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 0x09
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand

        if targetPID > 0 {
            // Activate the target app so its focused text field is ready to receive ⌘V.
            // Electron apps (WhatsApp, Telegram, etc.) require the app to be frontmost
            // for key events to reach the correct input element.
            if let app = NSRunningApplication(processIdentifier: targetPID) {
                app.activate(options: [])
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                down?.postToPid(targetPID)
                up?.postToPid(targetPID)
            }
        } else {
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            NSPasteboard.general.clearContents()
            if let previous { NSPasteboard.general.setString(previous, forType: .string) }
        }
    }
}
