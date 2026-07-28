import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let transcriptionService: TranscriptionService
    let correctionManager: CorrectionManager
    let powerModeManager: PowerModeManager
    let ollamaService: OllamaService

    @AppStorage("selectedModel") private var selectedModel = "openai_whisper-large-v3_turbo"
    @AppStorage("language") private var language = "nl"
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers = "control_option"
    @AppStorage("requiredSegmentsForConfirmation") private var requiredSegmentsForConfirmation: Int = 1
    @AppStorage("spokenCommandsEnabled") private var spokenCommandsEnabled = false
    @AppStorage("aiEnhanceEnabled") private var aiEnhanceEnabled = false
    @AppStorage("aiEnhanceModel") private var aiEnhanceModel = OllamaService.defaultModel
    @AppStorage("aiEnhanceMinWords") private var aiEnhanceMinWords = 8

    @State private var editingRuleID: UUID? = nil
    @State private var editLang: String = ""
    @State private var editWords: String = ""

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
            modelSection
            taalSection
            sneltoetsSection
            streamingSection
            commandosSection
            aiSection
            powerModeSection
        }
        .formStyle(.grouped)
        .task { await ollamaService.refresh() }
    }

    private var aiSection: some View {
        Section("AI-opschonen") {
            Toggle("Transcriptie opschonen via Ollama", isOn: $aiEnhanceEnabled)
            if aiEnhanceEnabled {
                switch ollamaService.status {
                case .available:
                    Picker("Model", selection: $aiEnhanceModel) {
                        // Houd de opgeslagen keuze geldig, ook als het model (nog) niet geïnstalleerd is
                        if !ollamaService.installedModels.contains(aiEnhanceModel) {
                            Text("\(aiEnhanceModel) (niet geïnstalleerd)").tag(aiEnhanceModel)
                        }
                        ForEach(ollamaService.installedModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    if ollamaService.installedModels.isEmpty {
                        Text("Geen modellen gevonden. Installeer er een met: ollama pull \(OllamaService.defaultModel)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Stepper(value: $aiEnhanceMinWords, in: 0...30) {
                        HStack {
                            Text("Overslaan onder")
                            Spacer()
                            Text("\(aiEnhanceMinWords) woorden")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                case .unavailable:
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Ollama niet gevonden op localhost:11434")
                            .font(.caption)
                        Spacer()
                        Button("Opnieuw") {
                            Task { await ollamaService.refresh() }
                        }
                    }
                case .unknown:
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Ollama zoeken...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("Stopwoorden, zelfcorrecties en interpunctie worden lokaal opgeschoond door een klein taalmodel. Bij een fout of als Ollama niet draait wordt de ruwe tekst geplakt.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modelSection: some View {
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
    }

    private var taalSection: some View {
        Section("Taal") {
            Picker("Standaard taal", selection: $language) {
                ForEach(languages, id: \.0) { lang in
                    Text(lang.1).tag(lang.0)
                }
            }
        }
    }

    private var sneltoetsSection: some View {
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

    private var streamingSection: some View {
        Section("Streaming") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Bevestigingsdrempel")
                    Spacer()
                    Text("\(requiredSegmentsForConfirmation)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: Binding(
                        get: { Double(requiredSegmentsForConfirmation) },
                        set: { requiredSegmentsForConfirmation = Int($0.rounded()) }
                    ),
                    in: 0...4,
                    step: 1
                )
            }
            Text("Lager = sneller bevestigde segmenten, minder context voor herstel. Aanbevolen: 1.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var commandosSection: some View {
        Section("Gesproken commando's") {
            Toggle("Interpunctie via stem", isOn: $spokenCommandsEnabled)
            Text("Zet gesproken woorden om naar leestekens: \"komma\" → ,  \"nieuwe paragraaf\" → ¶  enz. Standaard uit om false positives te vermijden.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var powerModeSection: some View {
        Section("Power Mode") {
            ForEach(powerModeManager.rules) { rule in
                if editingRuleID == rule.id {
                    powerModeEditRow(for: rule)
                } else {
                    powerModeRuleRow(for: rule)
                }
            }
            Button("Regel toevoegen...") {
                PowerModeManager.pickApp { rule in
                    guard let rule else { return }
                    powerModeManager.add(rule)
                    editingRuleID = rule.id
                    editLang = rule.language ?? ""
                    editWords = rule.promptWords.joined(separator: ", ")
                }
            }
            Text("Pas taal of woordenlijst automatisch aan op basis van de actieve app bij het dicteren.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func powerModeRuleRow(for rule: PowerModeRule) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.appName)
                    .font(.body)
                HStack(spacing: 6) {
                    if let lang = rule.language, let label = languages.first(where: { $0.0 == lang })?.1 {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Standaard taal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !rule.promptWords.isEmpty {
                        Text("· \(rule.promptWords.count) \(rule.promptWords.count == 1 ? "woord" : "woorden")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                editingRuleID = rule.id
                editLang = rule.language ?? ""
                editWords = rule.promptWords.joined(separator: ", ")
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Button {
                powerModeManager.delete(rule)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func powerModeEditRow(for rule: PowerModeRule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rule.appName)
                .font(.headline)
            Picker("Taal", selection: $editLang) {
                Text("Standaard").tag("")
                ForEach(languages, id: \.0) { lang in
                    Text(lang.1).tag(lang.0)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Woordenlijst")
                    .font(.caption)
                TextField("woord1, woord2, ...", text: $editWords)
                    .textFieldStyle(.roundedBorder)
            }
            Text("Vakwoorden die als hint meegegeven worden aan de transcriptie-decoder.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Annuleer") {
                    editingRuleID = nil
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Opslaan") {
                    var updated = rule
                    updated.language = editLang.isEmpty ? nil : editLang
                    updated.promptWords = editWords
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    powerModeManager.update(updated)
                    editingRuleID = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }
}
