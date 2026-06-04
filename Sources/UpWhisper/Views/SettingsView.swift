import SwiftUI

struct SettingsView: View {
    let transcriptionService: TranscriptionService

    @AppStorage("selectedModel") private var selectedModel = "openai_whisper-large-v3_turbo"
    @AppStorage("language") private var language = "nl"
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers = "control_option"

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
                        let installed = transcriptionService.installedModels.contains(model.0)
                        Text(installed ? "\(model.1) ✓" : model.1).tag(model.0)
                    }
                }
                .onChange(of: selectedModel) { _, newModel in
                    Task { await transcriptionService.loadModel(newModel) }
                }
                if transcriptionService.state == .loadingModel {
                    if transcriptionService.downloadProgress > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: transcriptionService.downloadProgress)
                            Text("Downloaden... \(Int(transcriptionService.downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Model laden...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !transcriptionService.installedModels.isEmpty {
                    let names = transcriptionService.installedModels
                        .compactMap { id in models.first { $0.0 == id }?.1.components(separatedBy: " ").first }
                        .joined(separator: " · ")
                    Text("Lokaal: \(names)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Taal") {
                Picker("Standaard taal", selection: $language) {
                    ForEach(languages, id: \.0) { lang in
                        Text(lang.1).tag(lang.0)
                    }
                }
            }
            Section("Sneltoets") {
                Picker("Toetsen", selection: $hotkeyModifiers) {
                    ForEach(HotkeyManager.options, id: \.id) { option in
                        Text(option.label).tag(option.id)
                    }
                }
                Text("Tik om opname te starten en stoppen. Houd de toetsen vast om op te nemen en laat los om te plakken.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
