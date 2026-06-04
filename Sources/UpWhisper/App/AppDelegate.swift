import AppKit
import SwiftUI
import ServiceManagement

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
    private var stopTask: Task<Void, Never>?
    private var isHotkeyPaused = false

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
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let loginItem = NSMenuItem(
            title: "Starten bij inloggen",
            action: #selector(toggleLoginItem),
            keyEquivalent: ""
        )
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        loginItem.target = self
        menu.addItem(loginItem)

        let pauseItem = NSMenuItem(
            title: "Pauzeer sneltoets",
            action: #selector(toggleHotkeyPause),
            keyEquivalent: ""
        )
        pauseItem.state = isHotkeyPaused ? .on : .off
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Afsluiten",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in self?.statusItem?.menu = nil }
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("[LoginItem] Fout: \(error)")
        }
    }

    @objc private func toggleHotkeyPause() {
        isHotkeyPaused.toggle()
        if isHotkeyPaused {
            hotkeyManager.unregister()
            toggleArmed = false
            hotkeyPressTime = nil
        } else {
            hotkeyManager.register()
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

    /// Grens tussen "tik" (toggle) en "vasthouden" (push-to-talk), in seconden.
    private let holdThreshold: TimeInterval = 0.4
    private var hotkeyPressTime: Date?
    /// True zodra een korte tik de opname in toggle-modus heeft gezet.
    private var toggleArmed = false

    private func setupHotkey() {
        hotkeyManager.onPress = { [weak self] in self?.hotkeyPressed() }
        hotkeyManager.onRelease = { [weak self] in self?.hotkeyReleased() }
        hotkeyManager.register()
    }

    private func hotkeyPressed() {
        if toggleArmed || coordinator.isRecording {
            // Opname loopt in toggle-modus → stoppen en plakken.
            toggleArmed = false
            hotkeyPressTime = nil
            stopAndPaste()
        } else {
            // Start opname; release bepaalt of het push-to-talk of toggle wordt.
            targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            hotkeyPressTime = Date()
            coordinator.toggle(pasteAfter: false)
        }
    }

    private func hotkeyReleased() {
        // Niet wachten op coordinator.isRecording — die is async en kan nog false zijn.
        guard let pressTime = hotkeyPressTime else { return }
        let held = Date().timeIntervalSince(pressTime)
        hotkeyPressTime = nil
        if held >= holdThreshold {
            // Vastgehouden → push-to-talk: stop en plak bij loslaten.
            toggleArmed = false
            stopAndPaste()
        } else {
            // Korte tik → toggle-modus: wacht op volgende druk om te stoppen.
            toggleArmed = true
        }
    }

    private func stopAndPaste() {
        stopTask?.cancel()
        popover?.performClose(nil)
        stopTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self.coordinator.toggle(pasteAfter: true, targetPID: self.targetPID)
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
        return NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Up/Whisper")!
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

    private func togglePopover() {
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
