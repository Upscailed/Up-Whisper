import SwiftUI

struct PopoverView: View {
    let transcriptionService: TranscriptionService
    let historyManager: HistoryManager

    @State private var recordingEngine = RecordingEngine()
    @State private var latestTranscription = ""
    @State private var showHistory = false
    @State private var copied = false
    @AppStorage("language") private var language = "nl"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if showHistory {
                HistoryView(historyManager: historyManager)
            } else {
                mainView
            }
        }
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Text("UpWhisper")
                .font(.headline)
            Spacer()
            Button {
                showHistory.toggle()
            } label: {
                Image(systemName: showHistory ? "mic.fill" : "clock")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var mainView: some View {
        VStack(spacing: 20) {
            Spacer()

            if transcriptionService.state == .loadingModel {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Model downloaden...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                RecordingButton(
                    isRecording: recordingEngine.isRecording,
                    audioLevel: recordingEngine.audioLevel,
                    action: handleRecordingToggle
                )

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !latestTranscription.isEmpty {
                    transcriptionOutput
                }
            }

            Spacer()
        }
        .padding(.vertical, 16)
    }

    private var transcriptionOutput: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                Text(latestTranscription)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 120)
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            Button(copied ? "Gekopieerd!" : "Kopieer tekst") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(latestTranscription, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
    }

    private var statusText: String {
        switch transcriptionService.state {
        case .idle: return "Model laden mislukt"
        case .loadingModel: return "Model downloaden..."
        case .ready: return recordingEngine.isRecording ? "Opname loopt..." : "Klik om op te nemen"
        case .transcribing: return "Transcriberen..."
        }
    }

    private func handleRecordingToggle() {
        Task {
            if recordingEngine.isRecording {
                if let url = recordingEngine.stopRecording() {
                    if let text = await transcriptionService.transcribe(audioURL: url, language: language) {
                        latestTranscription = text
                        historyManager.add(TranscriptionEntry(
                            text: text,
                            model: transcriptionService.defaultModel
                        ))
                    }
                    try? FileManager.default.removeItem(at: url)
                }
            } else {
                latestTranscription = ""
                _ = try? await recordingEngine.startRecording()
            }
        }
    }
}
