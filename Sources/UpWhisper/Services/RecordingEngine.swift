import AVFoundation
import Foundation

enum RecordingError: Error {
    case permissionDenied
    case setupFailed
}

@Observable
class RecordingEngine {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private(set) var isRecording = false
    private(set) var audioLevel: Float = 0
    private var outputURL: URL?

    func startRecording() async throws -> URL {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { throw RecordingError.permissionDenied }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        guard let file = try? AVAudioFile(forWriting: url, settings: format.settings) else {
            throw RecordingError.setupFailed
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? file.write(from: buffer)
            guard let data = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            let rms = sqrt(UnsafeBufferPointer(start: data, count: frameCount)
                .reduce(0.0) { $0 + Double($1 * $1) } / Double(frameCount))
            DispatchQueue.main.async { self?.audioLevel = Float(rms) }
        }

        try engine.start()
        audioEngine = engine
        audioFile = file
        outputURL = url
        isRecording = true
        return url
    }

    func stopRecording() -> URL? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        isRecording = false
        audioLevel = 0
        defer { outputURL = nil }
        return outputURL
    }
}
