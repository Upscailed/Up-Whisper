import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedModel") private var selectedModel = "openai_whisper-large-v3-turbo"
    @AppStorage("language") private var language = "nl"

    let models = [
        ("openai_whisper-large-v3-turbo", "large-v3-turbo (Aanbevolen)"),
        ("openai_whisper-small", "small (Snel, minder data)"),
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
        .frame(width: 360, height: 200)
        .navigationTitle("Instellingen")
    }
}
