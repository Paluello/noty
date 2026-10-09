import CoreGraphics
import Foundation

/// A shape recognized from a hand-drawn stroke (STR-7, ADR-0013).
public enum RecognizedShape: Equatable, Sendable {
    case line(CGPoint, CGPoint)
    case ellipse(CGRect)
    /// A closed polygon: triangles, rectangles and other quadrilaterals.
    case polygon([CGPoint])
}

/// Turns a stroke that ends with the Pencil held still into a clean shape.
///
/// Pure geometry, no UI: easy to test with synthetic strokes.
public enum ShapeRecognizer {
    /// How long the Pencil must stay still at the end of a stroke.
    public static let holdDuration: TimeInterval = 0.45
    /// How far it may wander while "still", in points.
    public static let holdTolerance: CGFloat = 6

    /// Index of the first point of the final hold, or `nil` if the stroke
    /// does not end with the Pencil held still.
    ///
    /// `liftTime` is when the Pencil left the screen, on the same clock as
    /// `times`: PencilKit adds no points while the Pencil does not move, so a
    /// hold often shows up only as a gap before the lift.
    public static func holdStart(locations: [CGPoint], times: [TimeInterval], liftTime: TimeInterval? = nil) -> Int? {
        guard locations.count == times.count, let end = locations.last, let lastTime = times.last else { return nil }
        let endTime = max(lastTime, liftTime ?? lastTime)
        var index = locations.count - 1
        while index > 0, distance(locations[index - 1], end) <= holdTolerance {
            index -= 1
        }
        guard endTime - times[index] >= holdDuration, index >= 4 else { return nil }
        return index
    }

    public static func recognize(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= 5 else { return nil }
        let length = pathLength(points)
        guard length > 30 else { return nil }
        let first = points[0], last = points[points.count - 1]
        let chord = distance(first, last)

        // Open and never far from the segment between its ends: a line.
        // (Measured against the chord: hand tremor makes the path longer, not wider.)
        if chord > 30 {
            let deviation = points.map { distanceFromSegment($0, first, last) }.max() ?? 0
            if deviation / chord < 0.06 {
                let (a, b) = snapToAxis(first, last)
                return .line(a, b)
            }
        }

        // Anything else must be (nearly) closed.
        guard chord < 0.2 * length else { return nil }

        let bounds = boundingBox(points)
        guard bounds.width > 20, bounds.height > 20 else { return nil }

        var corners = simplify(points, epsilon: 0.08 * max(bounds.width, bounds.height))
        if corners.count > 1, distance(corners[0], corners[corners.count - 1]) < 0.2 * max(bounds.width, bounds.height) {
            corners.removeLast()
        }

        switch corners.count {
        case 3:
            return .polygon(corners)
        case 4:
            return .polygon(isAxisAlignedRectangle(corners, in: bounds) ? rectangleCorners(bounds) : corners)
        default:
            return ellipseError(points, in: bounds) < 0.2 ? .ellipse(bounds) : nil
        }
    }

    /// Points along the ideal shape, about `spacing` apart, for a new stroke.
    public static func points(for shape: RecognizedShape, spacing: CGFloat = 4) -> [CGPoint] {
        switch shape {
        case .line(let a, let b):
            return interpolate(a, b, spacing: spacing, includeEnd: true)
        case .polygon(let corners):
            var result: [CGPoint] = []
            for (index, corner) in corners.enumerated() {
                result += interpolate(corner, corners[(index + 1) % corners.count], spacing: spacing, includeEnd: false)
            }
            result.append(corners[0])
            return result
        case .ellipse(let rect):
            let perimeter = .pi * (rect.width + rect.height) / 2
            let steps = max(24, Int(perimeter / spacing))
            return (0...steps).map { step in
                let angle = 2 * .pi * CGFloat(step) / CGFloat(steps) - .pi / 2
                return CGPoint(x: rect.midX + rect.width / 2 * cos(angle), y: rect.midY + rect.height / 2 * sin(angle))
            }
        }
    }

    // MARK: - Geometry

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    static func pathLength(_ points: [CGPoint]) -> CGFloat {
        zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    static func boundingBox(_ points: [CGPoint]) -> CGRect {
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    static func distanceFromSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return distance(p, a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return distance(p, CGPoint(x: a.x + t * dx, y: a.y + t * dy))
    }

    /// Ramer–Douglas–Peucker: keeps only the points that matter (the corners).
    static func simplify(_ points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let first = points[0], last = points[points.count - 1]
        var maxDistance: CGFloat = 0
        var index = 0
        // For closed strokes first ≈ last: measure from the first point instead.
        let isClosed = distance(first, last) < epsilon
        for i in 1..<(points.count - 1) {
            let d = isClosed ? distance(points[i], first) : distanceFromSegment(points[i], first, last)
            if d > maxDistance {
                maxDistance = d
                index = i
            }
        }
        if isClosed {
            // Split at the farthest point and simplify both halves.
            let left = simplify(Array(points[...index]), epsilon: epsilon)
            let right = simplify(Array(points[index...]), epsilon: epsilon)
            return Array(left.dropLast()) + right
        }
        guard maxDistance > epsilon else { return [first, last] }
        let left = simplify(Array(points[...index]), epsilon: epsilon)
        let right = simplify(Array(points[index...]), epsilon: epsilon)
        return Array(left.dropLast()) + right
    }

    /// Mean distance from the ellipse inscribed in `bounds`, relative to its size.
    static func ellipseError(_ points: [CGPoint], in bounds: CGRect) -> CGFloat {
        let a = bounds.width / 2, b = bounds.height / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let errors = points.map { p -> CGFloat in
            let value = pow((p.x - center.x) / a, 2) + pow((p.y - center.y) / b, 2)
            return abs(sqrt(value) - 1)
        }
        return errors.reduce(0, +) / CGFloat(errors.count)
    }

    static func isAxisAlignedRectangle(_ corners: [CGPoint], in bounds: CGRect) -> Bool {
        let tolerance = 0.15 * max(bounds.width, bounds.height)
        let boxCorners = rectangleCorners(bounds)
        return corners.allSatisfy { corner in boxCorners.contains { distance($0, corner) < tolerance } }
    }

    static func rectangleCorners(_ rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
    }

    /// Nearly horizontal or vertical lines become exactly so (within 6°).
    static func snapToAxis(_ a: CGPoint, _ b: CGPoint) -> (CGPoint, CGPoint) {
        let angle = abs(atan2(b.y - a.y, b.x - a.x))
        let threshold = 6 * CGFloat.pi / 180
        if angle < threshold || abs(angle - .pi) < threshold {
            return (a, CGPoint(x: b.x, y: a.y))
        }
        if abs(angle - .pi / 2) < threshold {
            return (a, CGPoint(x: a.x, y: b.y))
        }
        return (a, b)
    }

    static func interpolate(_ a: CGPoint, _ b: CGPoint, spacing: CGFloat, includeEnd: Bool) -> [CGPoint] {
        let steps = max(1, Int(distance(a, b) / spacing))
        let range = includeEnd ? Array(0...steps) : Array(0..<steps)
        return range.map { step in
            let t = CGFloat(step) / CGFloat(steps)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }
}
