import Foundation

struct TranscriptionEntry: Identifiable, Codable {
    let id: UUID
    var text: String
    let date: Date
    let model: String
    /// Ruwe transcriptie vóór AI-opschonen (Fase 17); nil als er niet is opgeschoond.
    /// Optioneel veld zodat bestaande history.json leesbaar blijft.
    var rawText: String?

    init(text: String, rawText: String? = nil, model: String) {
        self.id = UUID()
        self.text = text
        self.rawText = rawText
        self.date = Date()
        self.model = model
    }

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 60 ? String(trimmed.prefix(60)) + "..." : trimmed
    }
}
