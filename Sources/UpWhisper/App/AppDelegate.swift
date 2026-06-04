import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let transcriptionService = TranscriptionService()
    private let historyManager = HistoryManager()
    private lazy var coordinator = RecordingCoordinator(
        transcriptionService: transcriptionService,
        historyManager: historyManager
    )
    private let hotkeyManager = HotkeyManager()
    private var targetPID: pid_t = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupPopover()
        setupHotkey()
        startObservingCoordinator()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        let view = PopoverView(
            transcriptionService: transcriptionService,
            historyManager: historyManager,
            coordinator: coordinator
        )
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 460)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: view)
    }

    private func setupHotkey() {
        hotkeyManager.onTrigger = { [weak self] in
            self?.hotkeyTriggered()
        }
        hotkeyManager.register()
    }

    private func hotkeyTriggered() {
        if coordinator.isRecording {
            popover?.performClose(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self else { return }
                self.coordinator.toggle(pasteAfter: true, targetPID: self.targetPID)
            }
        } else {
            targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            coordinator.toggle(pasteAfter: false)
        }
    }

    private func startObservingCoordinator() {
        withObservationTracking {
            _ = coordinator.isRecording
            _ = coordinator.isProcessing
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateStatusIcon()
                self?.startObservingCoordinator()
            }
        }
        updateStatusIcon()
    }

    private func updateStatusIcon() {
        if coordinator.isRecording {
            statusItem?.button?.image = makeStatusImage(background: .systemRed)
        } else if coordinator.isProcessing {
            statusItem?.button?.image = makeStatusImage(background: .systemOrange)
        } else {
            statusItem?.button?.image = makeStatusImage(background: nil)
        }
    }

    private lazy var micGlyph: NSImage = {
        if let url = Bundle.module.url(forResource: "MenuBarMic", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "UpWhisper")!
    }()

    private func makeStatusImage(background: NSColor?) -> NSImage {
        guard let bg = background else {
            let icon = micGlyph.copy() as! NSImage
            let height: CGFloat = 18
            icon.size = NSSize(width: micGlyph.size.width * height / micGlyph.size.height, height: height)
            icon.isTemplate = true
            return icon
        }
        let size = NSSize(width: 22, height: 22)
        let glyphHeight: CGFloat = 14
        let glyphWidth = micGlyph.size.width * glyphHeight / micGlyph.size.height
        let glyph = micGlyph
        let image = NSImage(size: size, flipped: false) { rect in
            bg.setFill()
            NSBezierPath(ovalIn: rect).fill()
            let white = glyph.copy() as! NSImage
            white.lockFocus()
            NSColor.white.set()
            NSRect(origin: .zero, size: white.size).fill(using: .sourceAtop)
            white.unlockFocus()
            white.isTemplate = false
            let gRect = NSRect(
                x: (rect.width - glyphWidth) / 2,
                y: (rect.height - glyphHeight) / 2,
                width: glyphWidth,
                height: glyphHeight
            )
            white.draw(in: gRect)
            return true
        }
        image.isTemplate = false
        return image
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if let popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
