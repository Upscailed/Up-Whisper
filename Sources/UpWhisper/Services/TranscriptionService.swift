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

    let defaultModel = "openai_whisper-large-v3_turbo"

    private(set) var loadedModel = "openai_whisper-large-v3_turbo"

    init() {
        Task {
            let saved = UserDefaults.standard.string(forKey: "selectedModel") ?? defaultModel
            await loadModel(saved)
        }
    }

    func loadModel(_ modelName: String? = nil) async {
        state = .loadingModel
        lastError = nil
        let model = modelName ?? defaultModel
        do {
            print("[WhisperKit] Laden: \(model)")
            whisperKit = try await WhisperKit(model: model, verbose: true, logLevel: .debug, load: true)
            loadedModel = model
            print("[WhisperKit] Geladen: \(model)")
            state = .ready
        } catch {
            // Turbo niet beschikbaar — fallback naar large-v3
            print("[WhisperKit] '\(model)' niet gevonden, fallback naar openai_whisper-large-v3")
            do {
                whisperKit = try await WhisperKit(model: "openai_whisper-large-v3", verbose: true, logLevel: .debug, load: true)
                print("[WhisperKit] Geladen: openai_whisper-large-v3")
                state = .ready
            } catch {
                print("[WhisperKit] Fout: \(error)")
                lastError = error.localizedDescription
                state = .idle
            }
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

    func makeStreamTranscriber(
        language: String = "nl",
        callback: @escaping AudioStreamTranscriberCallback
    ) -> AudioStreamTranscriber? {
        guard let whisperKit, let tokenizer = whisperKit.tokenizer else { return nil }
        let options = DecodingOptions(language: language == "auto" ? nil : language)
        return AudioStreamTranscriber(
            audioEncoder: whisperKit.audioEncoder,
            featureExtractor: whisperKit.featureExtractor,
            segmentSeeker: whisperKit.segmentSeeker,
            textDecoder: whisperKit.textDecoder,
            tokenizer: tokenizer,
            audioProcessor: whisperKit.audioProcessor,
            decodingOptions: options,
            useVAD: true,
            stateChangeCallback: callback
        )
    }
}
