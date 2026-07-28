import SwiftUI

struct HistoryView: View {
    let historyManager: HistoryManager
    let correctionManager: CorrectionManager

    @State private var editingID: UUID? = nil
    @State private var editText: String = ""

    var body: some View {
        Group {
            if historyManager.entries.isEmpty {
                VStack {
                    Spacer()
                    Text("Nog geen transcripties")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(height: 300)
            } else {
                List(historyManager.entries) { entry in
                    if editingID == entry.id {
                        editRow(for: entry)
                    } else {
                        normalRow(for: entry)
                    }
                }
                .frame(height: 300)
            }
        }
    }

    @ViewBuilder
    private func normalRow(for entry: TranscriptionEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.preview)
                .font(.body)
                .lineLimit(2)
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.text, forType: .string)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                historyManager.delete(entry)
            } label: {
                Label("Verwijder", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            Button {
                editingID = entry.id
                editText = entry.text
            } label: {
                Label("Bewerk", systemImage: "pencil")
                    .labelStyle(.iconOnly)
            }
            .tint(.blue)
        }
    }

    @ViewBuilder
    private func editRow(for entry: TranscriptionEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let raw = entry.rawText {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ruwe transcriptie (vóór AI-opschonen)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(raw)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            TextEditor(text: $editText)
                .font(.body)
                .frame(minHeight: 60, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Button("Annuleer") {
                    editingID = nil
                    editText = ""
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Opslaan") {
                    let corrected = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if corrected != entry.text {
                        correctionManager.learnFrom(original: entry.text, corrected: corrected)
                    }
                    historyManager.update(entry, newText: corrected)
                    editingID = nil
                    editText = ""
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}
