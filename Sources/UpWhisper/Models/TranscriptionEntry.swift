import Foundation

struct TranscriptionEntry: Identifiable, Codable {
    let id: UUID
    var text: String
    let date: Date
    let model: String

    init(text: String, model: String) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.model = model
    }

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 60 ? String(trimmed.prefix(60)) + "..." : trimmed
    }
}
