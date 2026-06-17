import Foundation
import AppKit

struct PowerModeRule: Codable, Identifiable {
    var id: UUID
    var bundleID: String
    var appName: String
    var language: String?
    var promptWords: [String]

    init(bundleID: String, appName: String, language: String? = nil, promptWords: [String] = []) {
        self.id = UUID()
        self.bundleID = bundleID
        self.appName = appName
        self.language = language
        self.promptWords = promptWords
    }
}

@Observable
class PowerModeManager {
    private(set) var rules: [PowerModeRule] = []
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("UpWhisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("power-mode-rules.json")
        load()
    }

    func rule(forBundleID bundleID: String) -> PowerModeRule? {
        rules.first { $0.bundleID == bundleID }
    }

    func add(_ rule: PowerModeRule) {
        guard !rules.contains(where: { $0.bundleID == rule.bundleID }) else { return }
        rules.append(rule)
        save()
    }

    func update(_ rule: PowerModeRule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx] = rule
        save()
    }

    func delete(_ rule: PowerModeRule) {
        rules.removeAll { $0.id == rule.id }
        save()
    }

    static func pickApp(completion: @escaping (PowerModeRule?) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Kies een app voor Power Mode"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if #available(macOS 12, *) {
            panel.allowedContentTypes = [.applicationBundle]
        } else {
            panel.allowedFileTypes = ["app"]
        }
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            let bundle = Bundle(url: url)
            guard let bundleID = bundle?.bundleIdentifier else {
                completion(nil)
                return
            }
            let appName = url.deletingPathExtension().lastPathComponent
            completion(PowerModeRule(bundleID: bundleID, appName: appName))
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        try? data.write(to: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([PowerModeRule].self, from: data)
        else { return }
        rules = decoded
    }
}
