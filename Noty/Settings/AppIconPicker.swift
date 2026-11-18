import SwiftUI
import UIKit

/// The app icons a user can pick in Settings. Margin is the primary icon;
/// the others are alternate icons listed in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case margin = "Margine"
    case stroke = "Tratto"
    case ink = "Inchiostro"

    var id: String { rawValue }

    /// `nil` restores the primary icon.
    var alternateIconName: String? {
        self == .margin ? nil : "AppIcon-\(rawValue)"
    }

    var previewImageName: String { "IconPreview-\(rawValue)" }

    var title: LocalizedStringResource {
        switch self {
        case .margin: "Margin"
        case .stroke: "Stroke"
        case .ink: "Ink"
        }
    }

    static func from(alternateIconName: String?) -> AppIconChoice {
        allCases.first { $0.alternateIconName == alternateIconName } ?? .margin
    }
}

struct AppIconPicker: View {
    @State private var selection = AppIconChoice.from(
        alternateIconName: UIApplication.shared.alternateIconName
    )

    var body: some View {
        HStack(spacing: 24) {
            ForEach(AppIconChoice.allCases) { choice in
                Button {
                    select(choice)
                } label: {
                    VStack(spacing: 8) {
                        Image(choice.previewImageName)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .strokeBorder(.separator, lineWidth: 0.5)
                            }
                            .padding(3)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.accentColor, lineWidth: selection == choice ? 2.5 : 0)
                            }
                        Text(choice.title)
                            .font(.footnote)
                            .foregroundStyle(selection == choice ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(choice.title))
                .accessibilityAddTraits(selection == choice ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func select(_ choice: AppIconChoice) {
        guard choice != selection, UIApplication.shared.supportsAlternateIcons else { return }
        let previous = selection
        selection = choice
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(choice.alternateIconName)
            } catch {
                selection = previous
            }
        }
    }
}
