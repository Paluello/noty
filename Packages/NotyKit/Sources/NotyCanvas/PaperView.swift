import NotyCore
import UIKit

/// Shows a page's background pattern. It is separate from the drawing, so the
/// eraser never touches it and it stays vector-sharp in PDFs (ADR-0006).
///
/// All pages share one rendered image of the pattern: drawing each page on its
/// own would cost ~15 MB per page at high zoom.
final class PaperView: UIView {
    let style: PaperStyle

    init(style: PaperStyle, frame: CGRect) {
        self.style = style
        super.init(frame: frame)
        backgroundColor = .white
        isUserInteractionEnabled = false
        layer.contentsGravity = .resize
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show(_ image: CGImage?) {
        if layer.contents as! CGImage? !== image {
            layer.contents = image
        }
    }
}

/// One rendered paper image per style, size and scale, shared by every page.
@MainActor
final class PaperImageCache {
    private struct Key: Hashable {
        let style: PaperStyle
        let width: Int
        let height: Int
        let scale: Int
    }

    private var images: [Key: CGImage] = [:]

    func image(_ style: PaperStyle, size: CGSize, scale: CGFloat) -> CGImage? {
        // Round the scale so small zoom changes reuse the same image.
        let roundedScale = max(1, (scale * 2).rounded(.up) / 2)
        let key = Key(style: style, width: Int(size.width), height: Int(size.height), scale: Int(roundedScale * 100))
        if let image = images[key] {
            return image
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = roundedScale
        format.opaque = true
        let rect = CGRect(origin: .zero, size: size)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(rect)
            PaperRenderer.draw(style, in: rect, context: context.cgContext)
        }.cgImage
        // Keep only the current image: the old zoom level is not needed any more.
        images = [:]
        images[key] = image
        return image
    }
}

public enum PaperRenderer {
    static let lineSpacing: CGFloat = 24
    static let gridSpacing: CGFloat = 20
    static let topMargin: CGFloat = 72
    static let leftMargin: CGFloat = 64

    static let lineColor = UIColor(red: 0.62, green: 0.74, blue: 0.88, alpha: 1)
    static let marginColor = UIColor(red: 0.93, green: 0.55, blue: 0.55, alpha: 1)

    /// Line thickness multiplier that keeps lines visible when a page is drawn
    /// at `scale` (e.g. 0.3 for a thumbnail).
    public static func lineScale(forDrawingScale scale: CGFloat) -> CGFloat {
        max(1, 0.5 / (0.6 * scale))
    }

    /// Draws the pattern in page coordinates; also used for PDF export.
    /// `lineScale` thickens lines and dots for small previews.
    public static func draw(_ style: PaperStyle, in bounds: CGRect, context: CGContext, lineScale: CGFloat = 1) {
        context.saveGState()
        defer { context.restoreGState() }

        switch style {
        case .blank:
            break

        case .lined:
            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(0.6 * lineScale)
            var y = topMargin
            while y < bounds.maxY - lineSpacing / 2 {
                context.move(to: CGPoint(x: bounds.minX, y: y))
                context.addLine(to: CGPoint(x: bounds.maxX, y: y))
                y += lineSpacing
            }
            context.strokePath()
            context.setStrokeColor(marginColor.cgColor)
            context.move(to: CGPoint(x: leftMargin, y: bounds.minY))
            context.addLine(to: CGPoint(x: leftMargin, y: bounds.maxY))
            context.strokePath()

        case .grid:
            context.setStrokeColor(lineColor.withAlphaComponent(0.7).cgColor)
            context.setLineWidth(0.5 * lineScale)
            var x = gridSpacing
            while x < bounds.maxX {
                context.move(to: CGPoint(x: x, y: bounds.minY))
                context.addLine(to: CGPoint(x: x, y: bounds.maxY))
                x += gridSpacing
            }
            var y = gridSpacing
            while y < bounds.maxY {
                context.move(to: CGPoint(x: bounds.minX, y: y))
                context.addLine(to: CGPoint(x: bounds.maxX, y: y))
                y += gridSpacing
            }
            context.strokePath()

        case .dotted:
            context.setFillColor(lineColor.cgColor)
            let radius: CGFloat = 0.9 * lineScale
            var y = gridSpacing
            while y < bounds.maxY {
                var x = gridSpacing
                while x < bounds.maxX {
                    context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    x += gridSpacing
                }
                y += gridSpacing
            }
        }
    }
}
