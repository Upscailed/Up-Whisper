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
    private(set) var installedModels: [String] = []
    private var whisperKit: WhisperKit?

    private static let modelCacheBase = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appending(path: "huggingface/models/argmaxinc/whisperkit-coreml")

    let defaultModel = "openai_whisper-large-v3_turbo"

    private(set) var loadedModel = "openai_whisper-large-v3_turbo"

    init() {
        refreshInstalledModels()
        Task {
            let saved = UserDefaults.standard.string(forKey: "selectedModel") ?? defaultModel
            await loadModel(saved)
        }
    }

    func refreshInstalledModels() {
        let base = Self.modelCacheBase
        let known = ["openai_whisper-large-v3_turbo", "openai_whisper-small", "openai_whisper-medium", "openai_whisper-large-v3"]
        installedModels = known.filter {
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: base.appending(path: $0).path, isDirectory: &isDir) && isDir.boolValue
        }
    }

    func loadModel(_ modelName: String? = nil) async {
        state = .loadingModel
        lastError = nil
        downloadProgress = 0
        let model = modelName ?? defaultModel
        do {
            let url = try await Self.downloadWithProgress(variant: model) { [weak self] p in
                self?.downloadProgress = p
            }
            print("[WhisperKit] Laden: \(model)")
            whisperKit = try await WhisperKit(modelFolder: url.path, verbose: true, logLevel: .debug, load: true, download: false)
            loadedModel = model
            print("[WhisperKit] Geladen: \(model)")
            downloadProgress = 0
            refreshInstalledModels()
            state = .ready
        } catch {
            // Turbo niet beschikbaar — fallback naar large-v3
            print("[WhisperKit] '\(model)' niet gevonden, fallback naar openai_whisper-large-v3")
            downloadProgress = 0
            do {
                let fallbackURL = try await Self.downloadWithProgress(variant: "openai_whisper-large-v3") { [weak self] p in
                    self?.downloadProgress = p
                }
                whisperKit = try await WhisperKit(modelFolder: fallbackURL.path, verbose: true, logLevel: .debug, load: true, download: false)
                print("[WhisperKit] Geladen: openai_whisper-large-v3")
                downloadProgress = 0
                refreshInstalledModels()
                state = .ready
            } catch {
                print("[WhisperKit] Fout: \(error)")
                lastError = error.localizedDescription
                downloadProgress = 0
                state = .idle
            }
        }
    }

    private static func downloadWithProgress(
        variant: String,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        try await WhisperKit.download(variant: variant) { progress in
            Task { @MainActor in
                onProgress(progress.fractionCompleted)
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
