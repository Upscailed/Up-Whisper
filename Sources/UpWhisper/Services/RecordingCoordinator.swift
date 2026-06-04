import Foundation
import AVFoundation
import WhisperKit

@Observable
class RecordingCoordinator {
    private let transcriptionService: TranscriptionService
    private let historyManager: HistoryManager

    private(set) var isRecording = false
    private(set) var isProcessing = false
    private(set) var isTransitioning = false
    private(set) var liveText = ""
    private(set) var latestTranscription = ""
    private(set) var audioLevel: Float = 0
    private(set) var errorMessage: String?

    private var streamTranscriber: AudioStreamTranscriber?
    private var streamTask: Task<Void, Never>?

    init(transcriptionService: TranscriptionService, historyManager: HistoryManager) {
        self.transcriptionService = transcriptionService
        self.historyManager = historyManager
    }

    func toggle(pasteAfter: Bool = false, targetPID: pid_t = 0) {
        Task { @MainActor in
            guard !isTransitioning else { return }
            if isRecording {
                await stopStream(paste: pasteAfter, targetPID: targetPID)
            } else {
                startStream(pasteAfter: pasteAfter, targetPID: targetPID)
            }
        }
    }

    @MainActor
    private func startStream(pasteAfter: Bool, targetPID: pid_t) {
        guard AVCaptureDevice.default(for: .audio) != nil else {
            errorMessage = "Geen microfoon gevonden. Sluit een microfoon aan en probeer opnieuw."
            isTransitioning = false
            return
        }

        isTransitioning = true
        errorMessage = nil
        let lang = UserDefaults.standard.string(forKey: "language") ?? "nl"
        guard let transcriber = transcriptionService.makeStreamTranscriber(
            language: lang,
            callback: { [weak self] _, newState in
                guard let self else { return }
                let confirmed = newState.confirmedSegments.map { Self.strip($0.text) }.joined(separator: " ")
                let unconfirmed = newState.unconfirmedSegments.map { Self.strip($0.text) }.joined(separator: " ")
                let combined = [confirmed, unconfirmed].filter { !$0.isEmpty }.joined(separator: " ")
                let level = newState.bufferEnergy.last ?? 0
                Task { @MainActor [weak self] in
                    self?.liveText = combined
                    self?.audioLevel = level
                }
            }
        ) else { return }

        streamTranscriber = transcriber
        isRecording = true
        isTransitioning = false
        liveText = ""
        latestTranscription = ""

        streamTask = Task { [weak self] in
            do {
                try await transcriber.startStreamTranscription()
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, self.isRecording else { return }
                    self.isRecording = false
                    self.isProcessing = false
                    self.isTransitioning = false
                    self.streamTranscriber = nil
                    self.liveText = ""
                    self.errorMessage = "Microfoon niet beschikbaar. Controleer je systeeminstellingen."
                    print("[Recorder] Microfoon fout: \(error)")
                }
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private static func strip(_ text: String) -> String {
        text.replacingOccurrences(of: #"<\|[^|>]*\|>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func stopStream(paste: Bool, targetPID: pid_t) async {
        guard let transcriber = streamTranscriber else { return }
        isRecording = false
        isProcessing = true
        isTransitioning = true
        try? await Task.sleep(for: .milliseconds(1500))
        await transcriber.stopStreamTranscription()
        await streamTask?.value
        streamTask = nil
        streamTranscriber = nil

        let finalText = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        liveText = ""
        isProcessing = false
        isTransitioning = false
        if !finalText.isEmpty {
            latestTranscription = finalText
            historyManager.add(TranscriptionEntry(text: finalText, model: transcriptionService.loadedModel))
            if paste { PasteService.paste(finalText, targetPID: targetPID) }
        }
    }
}
