import Foundation

/// An audio recording inside a notebook (AUD-1, ADR-0010).
///
/// Saved as `audio/<id>/recording.json` plus one AAC file per minute
/// (`000.m4a`, `001.m4a`…): a crash loses at most the last minute (AUD-3).
public struct Recording: Codable, Hashable, Identifiable, Sendable {
    public struct Segment: Codable, Hashable, Sendable {
        public var fileName: String
        /// When this piece started; pauses leave gaps between segments.
        public var startDate: Date
        public var duration: TimeInterval

        public init(fileName: String, startDate: Date, duration: TimeInterval) {
            self.fileName = fileName
            self.startDate = startDate
            self.duration = duration
        }

        public var endDate: Date { startDate.addingTimeInterval(duration) }
    }

    public var id: UUID
    public var startDate: Date
    public var segments: [Segment]

    public init(id: UUID = UUID(), startDate: Date = .now, segments: [Segment] = []) {
        self.id = id
        self.startDate = startDate
        self.segments = segments
    }

    public var duration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    /// Position in the audio (pauses removed) of a moment, e.g. when a stroke
    /// was written; `nil` if nothing was being recorded then (AUD-2).
    public func audioTime(for date: Date) -> TimeInterval? {
        var elapsed: TimeInterval = 0
        for segment in segments {
            if date >= segment.startDate && date <= segment.endDate {
                return elapsed + date.timeIntervalSince(segment.startDate)
            }
            elapsed += segment.duration
        }
        return nil
    }

    /// The real-world moment that corresponds to a position in the audio.
    public func date(atAudioTime time: TimeInterval) -> Date? {
        var remaining = time
        for segment in segments {
            if remaining <= segment.duration {
                return segment.startDate.addingTimeInterval(max(0, remaining))
            }
            remaining -= segment.duration
        }
        return segments.last?.endDate
    }
}
