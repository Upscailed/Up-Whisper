import SwiftUI

struct RecordingButton: View {
    let isRecording: Bool
    let audioLevel: Float
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording {
                    Circle()
                        .fill(.red.opacity(0.15))
                        .frame(
                            width: 80 + CGFloat(audioLevel * 60),
                            height: 80 + CGFloat(audioLevel * 60)
                        )
                        .animation(.easeOut(duration: 0.08), value: audioLevel)
                }
                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: 72, height: 72)
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}
