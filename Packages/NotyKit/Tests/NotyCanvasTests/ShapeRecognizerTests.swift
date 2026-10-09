import CoreGraphics
import Foundation
import Testing
@testable import NotyCanvas

/// Synthetic "hand-drawn" strokes: ideal shapes with a deterministic wobble.
private func wobble(_ points: [CGPoint], amount: CGFloat = 2.5) -> [CGPoint] {
    points.enumerated().map { index, p in
        CGPoint(x: p.x + amount * sin(CGFloat(index) * 1.7), y: p.y + amount * cos(CGFloat(index) * 2.3))
    }
}

private func polyline(_ corners: [CGPoint], closed: Bool) -> [CGPoint] {
    let path = closed ? corners + [corners[0]] : corners
    var points: [CGPoint] = []
    for (a, b) in zip(path, path.dropFirst()) {
        points += ShapeRecognizer.interpolate(a, b, spacing: 3, includeEnd: false)
    }
    points.append(path.last!)
    return wobble(points)
}

@Suite struct ShapeRecognizerTests {
    @Test func recognizesAWobblyLineAndSnapsItHorizontal() throws {
        let stroke = polyline([CGPoint(x: 50, y: 100), CGPoint(x: 350, y: 108)], closed: false)
        guard case .line(let a, let b) = try #require(ShapeRecognizer.recognize(stroke)) else {
            Issue.record("Expected a line")
            return
        }
        #expect(a.y == b.y, "A nearly horizontal line becomes horizontal")
        #expect(abs(b.x - 350) < 6)
    }

    @Test func recognizesACircle() throws {
        let circle = (0...90).map { step -> CGPoint in
            let angle = CGFloat(step) / 90 * 2 * .pi
            return CGPoint(x: 200 + 80 * cos(angle), y: 200 + 80 * sin(angle))
        }
        guard case .ellipse(let rect) = try #require(ShapeRecognizer.recognize(wobble(circle))) else {
            Issue.record("Expected an ellipse")
            return
        }
        #expect(abs(rect.width - 160) < 10 && abs(rect.height - 160) < 10)
    }

    @Test func recognizesARectangleAndSquaresIt() throws {
        let corners = [CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 104), CGPoint(x: 298, y: 220), CGPoint(x: 102, y: 218)]
        guard case .polygon(let result) = try #require(ShapeRecognizer.recognize(polyline(corners, closed: true))) else {
            Issue.record("Expected a polygon")
            return
        }
        #expect(result.count == 4)
        #expect(result[0].y == result[1].y && result[1].x == result[2].x, "Snapped to an axis-aligned rectangle")
    }

    @Test func recognizesATriangle() throws {
        let corners = [CGPoint(x: 200, y: 50), CGPoint(x: 320, y: 250), CGPoint(x: 80, y: 250)]
        guard case .polygon(let result) = try #require(ShapeRecognizer.recognize(polyline(corners, closed: true))) else {
            Issue.record("Expected a polygon")
            return
        }
        #expect(result.count == 3)
    }

    @Test func ignoresHandwriting() {
        // A cursive "n": open, not straight.
        let scribble = (0...60).map { step -> CGPoint in
            let t = CGFloat(step) / 60
            return CGPoint(x: 100 + 200 * t, y: 200 - 60 * abs(sin(t * 2 * .pi)))
        }
        #expect(ShapeRecognizer.recognize(scribble) == nil)
        #expect(ShapeRecognizer.recognize([CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]) == nil)
    }

    @Test func detectsTheHoldAtTheEnd() {
        let moving: [CGPoint] = (0..<20).map { CGPoint(x: CGFloat($0) * 10, y: 0) }
        let still: [CGPoint] = (0..<10).map { CGPoint(x: 190 + CGFloat($0 % 2), y: 1) }
        let points = moving + still
        let movingTimes: [TimeInterval] = (0..<20).map { TimeInterval($0) * 0.01 }
        let stillTimes: [TimeInterval] = (0..<10).map { 0.2 + TimeInterval($0) * 0.06 }
        let times = movingTimes + stillTimes

        #expect(ShapeRecognizer.holdStart(locations: points, times: times) == 19)

        let quickTimes: [TimeInterval] = (0..<30).map { TimeInterval($0) * 0.01 }
        #expect(
            ShapeRecognizer.holdStart(locations: moving, times: movingTimes, liftTime: 0.19 + 0.6) == 19,
            "No points while still, but the Pencil lifted later: that is a hold"
        )
        #expect(ShapeRecognizer.holdStart(locations: points, times: quickTimes) == nil, "Lifting right away is not a hold")
    }

    @Test func generatedPointsFollowTheShape() {
        let points = ShapeRecognizer.points(for: .polygon(ShapeRecognizer.rectangleCorners(CGRect(x: 0, y: 0, width: 100, height: 50))))
        #expect(points.first == points.last, "Polygons are closed")
        #expect(points.count > 60)
        let ellipse = ShapeRecognizer.points(for: .ellipse(CGRect(x: 0, y: 0, width: 100, height: 100)))
        #expect(ellipse.allSatisfy { abs(ShapeRecognizer.distance($0, CGPoint(x: 50, y: 50)) - 50) < 0.01 })
    }
}
