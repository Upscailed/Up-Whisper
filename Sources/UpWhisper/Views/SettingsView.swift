import SwiftUI

struct SettingsView: View {
    let transcriptionService: TranscriptionService

    @AppStorage("selectedModel") private var selectedModel = "openai_whisper-large-v3_turbo"
    @AppStorage("language") private var language = "nl"

    let models = [
        ("openai_whisper-large-v3_turbo", "large-v3-turbo (Aanbevolen)"),
        ("openai_whisper-small", "small (Snel, minder accuraat)"),
        ("openai_whisper-medium", "medium"),
        ("openai_whisper-large-v3", "large-v3 (Beste kwaliteit)")
    ]

    let languages = [
        ("nl", "Nederlands"),
        ("en", "Engels"),
        ("auto", "Automatisch detecteren")
    ]

    var body: some View {
        Form {
            Section("Model") {
                Picker("Whisper model", selection: $selectedModel) {
                    ForEach(models, id: \.0) { model in
                        Text(model.1).tag(model.0)
                    }
                }
                .onChange(of: selectedModel) { _, newModel in
                    Task { await transcriptionService.loadModel(newModel) }
                }
                if transcriptionService.state == .loadingModel {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Model laden...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Taal") {
                Picker("Standaard taal", selection: $language) {
                    ForEach(languages, id: \.0) { lang in
                        Text(lang.1).tag(lang.0)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
