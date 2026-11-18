import SwiftUI

/// The app's only check of the OS version for its chrome (ADR-0024).
///
/// On iPadOS 26 and later every surface is the system's Liquid Glass
/// (`glassEffect`, `GlassEffectContainer`, the `.glass` button styles).
/// On iPadOS 18, which has no Liquid Glass, the same surfaces use that
/// version's standard system look: bar material and bordered buttons.
struct SystemGlass: Equatable {
    var tint: Color?
    var isInteractive = false
    /// No glass at all: the surface shows only its content.
    var isIdentity = false

    static let regular = SystemGlass()
    static let identity = SystemGlass(isIdentity: true)

    func tint(_ color: Color?) -> SystemGlass {
        var copy = self
        copy.tint = color
        return copy
    }

    func interactive(_ isEnabled: Bool = true) -> SystemGlass {
        var copy = self
        copy.isInteractive = isEnabled
        return copy
    }

    @available(iOS 26, *)
    var glass: Glass {
        if isIdentity { return .identity }
        return Glass.regular.tint(tint).interactive(isInteractive)
    }
}

extension View {
    /// Liquid Glass in `shape` on iPadOS 26+, the system bar material before.
    @ViewBuilder
    func systemGlass(_ style: SystemGlass = .regular, in shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            glassEffect(style.glass, in: shape)
        } else if style.isIdentity {
            self
        } else {
            background {
                ZStack {
                    shape.fill(.bar)
                    if let tint = style.tint {
                        shape.fill(tint)
                    }
                }
            }
        }
    }

    /// `.glass` (or `.glassProminent`) on iPadOS 26+, `.bordered` (or
    /// `.borderedProminent`) before.
    @ViewBuilder
    func systemGlassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        }
    }
}

/// A `GlassEffectContainer` on iPadOS 26+, so nearby glass shapes blend;
/// before, just the content.
struct SystemGlassContainer<Content: View>: View {
    var spacing: CGFloat?
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension ButtonRole {
    /// `.confirm` (the prominent glass checkmark) on iPadOS 26+; before,
    /// no role: the toolbar's confirmation placement already makes it bold.
    static var systemConfirm: ButtonRole? {
        if #available(iOS 26, *) {
            return .confirm
        }
        return nil
    }
}
