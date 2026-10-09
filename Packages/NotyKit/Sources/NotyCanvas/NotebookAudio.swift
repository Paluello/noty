import AVFoundation
import NotyCore
import Observation
import os

private let log = Logger(subsystem: "io.github.paluello.noty", category: "audio")

/// Records lectures and plays them back in sync with the ink (AUD-1, AUD-2, ADR-0010).
///
/// Audio is written in one-minute AAC segments, so a crash loses at most the
/// last minute (AUD-3). Recording goes on when the iPad is locked or another
/// app is in front (background audio mode).
@MainActor @Observable
public final class NotebookAudio {
    public static let segmentLength: TimeInterval = 60

    public private(set) var recordings: [Recording]

    // Recording
    public private(set) var isRecording = false
    public private(set) var isRecordingPaused = false
    public private(set) var recordedTime: TimeInterval = 0

    // Playback
    public private(set) var playing: Recording?
    public private(set) var isPlaying = false
    public private(set) var playbackTime: TimeInterval = 0
    public var rate: Float = 1 {
        didSet { if isPlaying { player?.rate = rate } }
    }
    /// The moment of the lecture being heard: ink written later is dimmed.
    public private(set) var playbackDate: Date?

    private let package: NotebookPackage
    private var current: Recording?
    private var recorder: AVAudioRecorder?
    private var segmentStart: Date?
    private var segmentTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var interruptionObserver: (any NSObjectProtocol)?

    public init(package: NotebookPackage) {
        self.package = package
        self.recordings = package.readRecordings()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            MainActor.assumeIsolated {
                // A call or Siri: pause, and leave a gap in the timeline.
                if type == .began, self?.isRecording == true, self?.isRecordingPaused == false {
                    self?.pauseRecording()
                }
            }
        }
    }

    public var isBusy: Bool { isRecording || playing != nil }

    // MARK: - Recording

    public func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    public func startRecording() throws {
        stopPlayback()
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try AVAudioSession.sharedInstance().setActive(true)
        let recording = Recording()
        current = recording
        try package.writeRecording(recording)
        isRecording = true
        isRecordingPaused = false
        recordedTime = 0
        try startSegment()
        startTicking()
    }

    public func pauseRecording() {
        guard isRecording, !isRecordingPaused else { return }
        finishSegment()
        isRecordingPaused = true
    }

    public func resumeRecording() {
        guard isRecording, isRecordingPaused else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try startSegment()
            isRecordingPaused = false
        } catch {
            log.error("Resume failed: \(error)")
        }
    }

    public func stopRecording() {
        guard isRecording else { return }
        if !isRecordingPaused {
            finishSegment()
        }
        isRecording = false
        isRecordingPaused = false
        tickTask?.cancel()
        if let current, current.segments.isEmpty {
            try? package.deleteRecording(current.id)
        }
        current = nil
        recordings = package.readRecordings()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startSegment() throws {
        guard let recording = current else { return }
        let fileName = String(format: "%03d.m4a", recording.segments.count)
        let url = try package.recordingFolder(recording.id).appending(path: fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.record() else { throw CocoaError(.fileWriteUnknown) }
        self.recorder = recorder
        segmentStart = .now

        // Close this file after a minute and go on in a new one.
        segmentTask?.cancel()
        segmentTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.segmentLength))
            guard !Task.isCancelled, let self, self.isRecording, !self.isRecordingPaused else { return }
            self.finishSegment()
            do {
                try self.startSegment()
            } catch {
                log.error("Next segment failed: \(error)")
                self.stopRecording()
            }
        }
    }

    private func finishSegment() {
        segmentTask?.cancel()
        guard let recorder, let segmentStart, var recording = current else { return }
        let duration = recorder.currentTime > 0 ? recorder.currentTime : Date.now.timeIntervalSince(segmentStart)
        recorder.stop()
        self.recorder = nil
        recording.segments.append(.init(fileName: recorder.url.lastPathComponent, startDate: segmentStart, duration: duration))
        current = recording
        do {
            try package.writeRecording(recording)
        } catch {
            log.error("Saving the recording failed: \(error)")
        }
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { return }
                let done = self.current?.duration ?? 0
                let live = self.isRecordingPaused ? 0 : (self.recorder?.currentTime ?? 0)
                self.recordedTime = done + live
            }
        }
    }

    // MARK: - Playback

    /// Plays a recording from `time` seconds into the audio.
    public func play(_ recording: Recording, from time: TimeInterval = 0) async {
        if playing?.id != recording.id {
            stopPlayback()
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                try AVAudioSession.sharedInstance().setActive(true)
                let item = try await Self.playerItem(for: recording, in: package)
                let player = AVPlayer(playerItem: item)
                self.player = player
                playing = recording
                timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak self] time in
                    MainActor.assumeIsolated {
                        self?.updatePosition(time.seconds)
                    }
                }
            } catch {
                log.error("Playback failed: \(error)")
                return
            }
        }
        seek(to: time)
        player?.rate = rate
        isPlaying = true
    }

    public func pausePlayback() {
        player?.pause()
        isPlaying = false
    }

    public func resumePlayback() {
        player?.rate = rate
        isPlaying = true
    }

    public func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, playing?.duration ?? 0))
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updatePosition(clamped)
    }

    /// Jumps to the moment a stroke was written, if this recording covers it (AUD-2).
    public func seek(toDate date: Date) {
        guard let recording = playing ?? recordings.last(where: { $0.audioTime(for: date) != nil }),
              let time = recording.audioTime(for: date)
        else { return }
        if playing?.id == recording.id {
            seek(to: time)
        } else {
            Task { await play(recording, from: time) }
        }
    }

    public func stopPlayback() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
        playing = nil
        isPlaying = false
        playbackTime = 0
        playbackDate = nil
    }

    public func delete(_ recording: Recording) {
        if playing?.id == recording.id {
            stopPlayback()
        }
        try? package.deleteRecording(recording.id)
        recordings = package.readRecordings()
    }

    private func updatePosition(_ seconds: TimeInterval) {
        guard let playing, seconds.isFinite else { return }
        playbackTime = seconds
        playbackDate = playing.date(atAudioTime: seconds)
        if seconds >= playing.duration - 0.05 {
            isPlaying = false
        }
    }

    /// The segments joined into one item, so the timeline is continuous.
    private static func playerItem(for recording: Recording, in package: NotebookPackage) async throws -> AVPlayerItem {
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CocoaError(.fileReadUnknown)
        }
        var cursor = CMTime.zero
        for segment in recording.segments {
            let asset = AVURLAsset(url: package.segmentURL(segment, of: recording))
            guard let source = try await asset.loadTracks(withMediaType: .audio).first else { continue }
            let duration = try await asset.load(.duration)
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: cursor)
            cursor = cursor + duration
        }
        return AVPlayerItem(asset: composition)
    }
}
