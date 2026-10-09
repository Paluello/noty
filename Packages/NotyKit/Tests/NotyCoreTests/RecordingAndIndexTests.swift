import Foundation
import Testing
@testable import NotyCore

@Suite struct RecordingAndIndexTests {
    let start = Date(timeIntervalSince1970: 1_760_000_000)
    /// Two minutes of audio with a 30-second pause in between.
    let recording: Recording

    init() {
        recording = Recording(startDate: start, segments: [
            .init(fileName: "000.m4a", startDate: start, duration: 60),
            .init(fileName: "001.m4a", startDate: start.addingTimeInterval(90), duration: 60),
        ])
    }

    @Test func mapsStrokeTimesToAudioSkippingPauses() {
        #expect(recording.duration == 120)
        #expect(recording.audioTime(for: start.addingTimeInterval(10)) == 10)
        #expect(recording.audioTime(for: start.addingTimeInterval(100)) == 70)
        #expect(recording.audioTime(for: start.addingTimeInterval(75)) == nil, "During the pause")
        #expect(recording.audioTime(for: start.addingTimeInterval(-5)) == nil)

        #expect(recording.date(atAudioTime: 70) == start.addingTimeInterval(100))
        #expect(recording.date(atAudioTime: 500) == start.addingTimeInterval(150))
    }

    @Test func recordingsAndIndexAreStoredInTheNotebook() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).noty")
        let manifest = NotebookManifest(title: "Lezione", paper: .lined, pageIDs: [UUID(), UUID()])
        let package = try NotebookPackage.create(at: url, manifest: manifest)

        try package.writeRecording(recording)
        #expect(package.readRecordings() == [recording])

        // Milliseconds survive saving, so strokes and audio line up.
        let precise = Recording(startDate: start.addingTimeInterval(0.25), segments: [
            .init(fileName: "000.m4a", startDate: start.addingTimeInterval(0.25), duration: 1.5),
        ])
        try package.writeRecording(precise)
        #expect(package.readRecordings().last?.segments.first?.startDate == precise.segments[0].startDate)
        try package.deleteRecording(precise.id)
        #expect(package.segmentURL(recording.segments[1], of: recording).lastPathComponent == "001.m4a")

        var index = TextIndex()
        index.pages[manifest.pageIDs[1]] = .init(text: "Teorema di Pitagora", pageModifiedAt: start)
        try package.writeTextIndex(index)
        #expect(package.readTextIndex() == index)
        let json = try String(contentsOf: url.appending(path: "text-index.json"), encoding: .utf8)
        #expect(json.contains("\"\(manifest.pageIDs[1].uuidString)\":"), "Pages are keyed by id")
        #expect(index.pages(matching: "pitagora", order: manifest.pageIDs) == [1])
        #expect(index.pages(matching: "Euclide", order: manifest.pageIDs).isEmpty)

        try package.deleteRecording(recording.id)
        #expect(package.readRecordings().isEmpty)
    }

    @Test func handwritingSearchSkipsLockedNotebooks() throws {
        let library = Library(root: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory))
        try library.prepare()
        let open = try library.createNotebook(title: "Aperto", in: library.root, paper: .grid)
        let locked = try library.createNotebook(title: "Segreto", in: library.root, paper: .grid)
        for package in [open, locked] {
            var index = TextIndex()
            index.pages[try package.readManifest().pageIDs[0]] = .init(text: "derivata", pageModifiedAt: start)
            try package.writeTextIndex(index)
        }
        var manifest = try locked.readManifest()
        manifest.isLocked = true
        try locked.writeManifest(manifest)

        let results = library.searchHandwriting("Derivata")
        #expect(results.map(\.entry.name) == ["Aperto"])
        #expect(results.first?.pages == [0])
    }
}
