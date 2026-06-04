import SwiftUI

struct PopoverView: View {
    let transcriptionService: TranscriptionService
    let historyManager: HistoryManager
    let coordinator: RecordingCoordinator

    @State private var showHistory = false
    @State private var showSettings = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if showSettings {
                SettingsView(transcriptionService: transcriptionService)
            } else if showHistory {
                HistoryView(historyManager: historyManager)
            } else {
                mainView
            }
        }
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Text("Up/Whisper")
                .font(.headline)
            Spacer()
            Button {
                showSettings = false
                showHistory.toggle()
            } label: {
                Image(systemName: showHistory ? "mic.fill" : "clock")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            Button {
                showHistory = false
                showSettings.toggle()
            } label: {
                Image(systemName: showSettings ? "mic.fill" : "gear")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
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
            } else if transcriptionService.state == .idle, let error = transcriptionService.lastError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Model laden mislukt:")
                        .font(.caption.bold())
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                    Button("Opnieuw proberen") {
                        Task { await transcriptionService.loadModel() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                RecordingButton(
                    isRecording: coordinator.isRecording,
                    audioLevel: coordinator.audioLevel,
                    action: { coordinator.toggle() }
                )

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !coordinator.latestTranscription.isEmpty {
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
                Text(coordinator.latestTranscription)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 120)
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            Button(copied ? "Gekopieerd!" : "Kopieer tekst") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(coordinator.latestTranscription, forType: .string)
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
        case .ready: return coordinator.isRecording ? "Opname loopt..." : "Klik om op te nemen"
        case .transcribing: return "Transcriberen..."
        }
    }
}
