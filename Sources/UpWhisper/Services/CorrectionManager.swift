import Foundation

struct CorrectionPair: Codable {
    var wrong: String
    var correct: String
}

@Observable
class CorrectionManager {
    private(set) var corrections: [CorrectionPair] = []
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("UpWhisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("corrections.json")
        load()
    }

    func learnFrom(original: String, corrected: String) {
        for pair in extractPairs(original: original, corrected: corrected) {
            if let idx = corrections.firstIndex(where: { $0.wrong.lowercased() == pair.wrong.lowercased() }) {
                corrections[idx] = pair
            } else {
                corrections.append(pair)
            }
        }
        save()
    }

    func apply(to text: String) -> String {
        var result = text
        for pair in corrections {
            guard !pair.wrong.isEmpty, !pair.correct.isEmpty else { continue }
            let escaped = NSRegularExpression.escapedPattern(for: pair.wrong)
            result = result.replacingOccurrences(
                of: "(?i)\\b\(escaped)\\b",
                with: pair.correct,
                options: .regularExpression
            )
        }
        return result
    }

    var vocabularyWords: [String] {
        Array(Set(corrections.map { $0.correct }.filter { !$0.isEmpty }))
    }

    private func extractPairs(original: String, corrected: String) -> [CorrectionPair] {
        let origWords = original.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let corrWords = corrected.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard origWords.count == corrWords.count else { return [] }
        return zip(origWords, corrWords).compactMap { orig, corr in
            guard orig.lowercased() != corr.lowercased(), !orig.isEmpty, !corr.isEmpty else { return nil }
            return CorrectionPair(wrong: orig, correct: corr)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(corrections) else { return }
        try? data.write(to: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CorrectionPair].self, from: data)
        else { return }
        corrections = decoded
    }
}
