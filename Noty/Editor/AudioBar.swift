import NotyCanvas
import NotyCore
import SwiftUI

/// Screen 5: recording or playback controls, floating at the bottom (AUD-1, AUD-2).
struct AudioBar: View {
    @Bindable var audio: NotebookAudio

    var body: some View {
        Group {
            if audio.isRecording {
                recordingControls
            } else if let recording = audio.playing {
                playbackControls(recording)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var recordingControls: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
                .opacity(audio.isRecordingPaused ? 0.3 : 1)
                .symbolEffect(.pulse, isActive: !audio.isRecordingPaused)
            Text(audio.isRecordingPaused ? "Paused" : "Recording")
                .font(.callout.weight(.semibold))
            Text(Duration.seconds(audio.recordedTime), format: .time(pattern: .minuteSecond))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(audio.isRecordingPaused ? "Resume" : "Pause", systemImage: audio.isRecordingPaused ? "record.circle" : "pause.fill") {
                if audio.isRecordingPaused {
                    audio.resumeRecording()
                } else {
                    audio.pauseRecording()
                }
            }
            .labelStyle(.iconOnly)
            Button("Stop", systemImage: "stop.fill", action: audio.stopRecording)
                .labelStyle(.iconOnly)
                .tint(.red)
        }
        .font(.title3)
        .frame(height: 44)
    }

    private func playbackControls(_ recording: Recording) -> some View {
        HStack(spacing: 14) {
            Button(audio.isPlaying ? "Pause" : "Play", systemImage: audio.isPlaying ? "pause.fill" : "play.fill") {
                if audio.isPlaying {
                    audio.pausePlayback()
                } else if audio.playbackTime >= recording.duration - 0.1 {
                    Task { await audio.play(recording, from: 0) }
                } else {
                    audio.resumePlayback()
                }
            }
            .labelStyle(.iconOnly)
            .font(.title3)

            Text(Duration.seconds(audio.playbackTime), format: .time(pattern: .minuteSecond))
                .font(.callout.monospacedDigit())
            Slider(
                value: Binding(get: { audio.playbackTime }, set: { audio.seek(to: $0) }),
                in: 0...max(recording.duration, 1)
            )
            .frame(width: 260)
            Text(Duration.seconds(recording.duration), format: .time(pattern: .minuteSecond))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)

            Menu {
                Picker("Speed", selection: $audio.rate) {
                    ForEach([Float(0.75), 1, 1.25, 1.5, 2], id: \.self) { rate in
                        Text(verbatim: "\(rate.formatted())×").tag(rate)
                    }
                }
            } label: {
                Text(verbatim: "\(audio.rate.formatted())×")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 40)
            }

            Button("Close", systemImage: "xmark", action: audio.stopPlayback)
                .labelStyle(.iconOnly)
        }
        .frame(height: 44)
    }
}

/// "Recordings" submenu: tap one to play it; delete from the last item.
struct RecordingsMenu: View {
    let audio: NotebookAudio

    var body: some View {
        ForEach(audio.recordings.reversed()) { recording in
            Button {
                Task { await audio.play(recording) }
            } label: {
                Label {
                    Text(recording.startDate, format: .dateTime.day().month().hour().minute())
                    Text(Duration.seconds(recording.duration), format: .time(pattern: .minuteSecond))
                } icon: {
                    Image(systemName: "play.fill")
                }
            }
        }
        Divider()
        Menu {
            ForEach(audio.recordings.reversed()) { recording in
                Button(role: .destructive) {
                    audio.delete(recording)
                } label: {
                    Text(recording.startDate, format: .dateTime.day().month().hour().minute())
                }
            }
        } label: {
            Label("Delete Recording", systemImage: "trash")
        }
    }
}
