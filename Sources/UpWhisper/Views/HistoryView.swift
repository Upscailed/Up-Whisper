import SwiftUI

struct HistoryView: View {
    let historyManager: HistoryManager

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
                    .swipeActions {
                        Button(role: .destructive) {
                            historyManager.delete(entry)
                        } label: {
                            Label("Verwijder", systemImage: "trash")
                        }
                    }
                }
                .frame(height: 300)
            }
        }
    }
}
