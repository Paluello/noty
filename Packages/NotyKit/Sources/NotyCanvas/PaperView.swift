import NotyCore
import UIKit

/// Draws a page's background pattern. It is separate from the drawing, so the
/// eraser never touches it and it stays vector-sharp in PDFs (ADR-0006).
final class PaperView: UIView {
    let style: PaperStyle

    init(style: PaperStyle, frame: CGRect) {
        self.style = style
        super.init(frame: frame)
        backgroundColor = .white
        isUserInteractionEnabled = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        PaperRenderer.draw(style, in: bounds, context: context)
    }
}

public enum PaperRenderer {
    static let lineSpacing: CGFloat = 24
    static let gridSpacing: CGFloat = 20
    static let topMargin: CGFloat = 72
    static let leftMargin: CGFloat = 64

    static let lineColor = UIColor(red: 0.62, green: 0.74, blue: 0.88, alpha: 1)
    static let marginColor = UIColor(red: 0.93, green: 0.55, blue: 0.55, alpha: 1)

    /// Draws the pattern in page coordinates; also used for PDF export.
    public static func draw(_ style: PaperStyle, in bounds: CGRect, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        switch style {
        case .blank:
            break

        case .lined:
            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(0.6)
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
            context.setLineWidth(0.5)
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
            let radius: CGFloat = 0.9
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
