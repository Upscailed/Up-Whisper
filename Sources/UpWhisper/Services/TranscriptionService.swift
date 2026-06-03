import WhisperKit
import Foundation

enum TranscriptionState {
    case idle, loadingModel, ready, transcribing
}

@Observable
class TranscriptionService {
    private(set) var state: TranscriptionState = .idle
    private(set) var downloadProgress: Double = 0
    private(set) var lastError: String?
    private var whisperKit: WhisperKit?

    let defaultModel = "openai_whisper-large-v3-turbo"

    init() {
        Task { await loadModel() }
    }

    func loadModel(_ modelName: String? = nil) async {
        state = .loadingModel
        lastError = nil
        do {
            let model = modelName ?? defaultModel
            whisperKit = try await WhisperKit(
                model: model,
                verbose: false,
                logLevel: .none
            )
            state = .ready
        } catch {
            lastError = error.localizedDescription
            state = .idle
        }
    }

    func transcribe(audioURL: URL, language: String = "nl") async -> String? {
        guard let whisperKit else { return nil }
        state = .transcribing
        defer { state = .ready }
        do {
            let options = DecodingOptions(language: language == "auto" ? nil : language)
            let results = try await whisperKit.transcribe(audioPath: audioURL.path, decodeOptions: options)
            return results.first?.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
}
