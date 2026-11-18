import NotyCanvas
import Observation
import SwiftUI

/// A palette of exactly 8 colors (STR-5).
struct ColorPalette: Codable, Identifiable, Hashable {
    static let standardID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var id: UUID
    var name: String
    var colors: [String]

    var isStandard: Bool { id == Self.standardID }

    var displayName: String {
        isStandard ? String(localized: "Standard") : name
    }

    var uiColors: [UIColor] { colors.map(UIColor.init(hex:)) }

    static let standard = ColorPalette(id: standardID, name: "Standard", colors: Palette.standard.map(\.hex))
}

/// The user's palettes, saved in UserDefaults; the standard one cannot be changed.
@MainActor @Observable
final class PaletteStore {
    private static let palettesKey = "palettes"
    private static let selectedKey = "selectedPalette"

    private(set) var palettes: [ColorPalette]
    var selectedID: UUID {
        didSet { UserDefaults.standard.set(selectedID.uuidString, forKey: Self.selectedKey) }
    }

    init() {
        let custom = UserDefaults.standard.data(forKey: Self.palettesKey)
            .flatMap { try? JSONDecoder().decode([ColorPalette].self, from: $0) } ?? []
        palettes = [.standard] + custom
        selectedID = UserDefaults.standard.string(forKey: Self.selectedKey).flatMap(UUID.init(uuidString:)) ?? ColorPalette.standardID
        if !palettes.contains(where: { $0.id == selectedID }) {
            selectedID = ColorPalette.standardID
        }
    }

    var selected: ColorPalette {
        palettes.first { $0.id == selectedID } ?? .standard
    }

    var selectedColors: [UIColor] { selected.uiColors }

    /// Creates a new palette starting from the selected one.
    @discardableResult
    func addPalette() -> ColorPalette {
        let name = String(localized: "Palette \(palettes.count)")
        let palette = ColorPalette(id: UUID(), name: name, colors: selected.colors)
        palettes.append(palette)
        save()
        return palette
    }

    func update(_ palette: ColorPalette) {
        guard !palette.isStandard, let index = palettes.firstIndex(where: { $0.id == palette.id }) else { return }
        palettes[index] = palette
        save()
    }

    func delete(_ palette: ColorPalette) {
        guard !palette.isStandard else { return }
        palettes.removeAll { $0.id == palette.id }
        if selectedID == palette.id {
            selectedID = ColorPalette.standardID
        }
        save()
    }

    private func save() {
        let custom = palettes.filter { !$0.isStandard }
        UserDefaults.standard.set(try? JSONEncoder().encode(custom), forKey: Self.palettesKey)
    }
}

/// Lists, selects, creates and deletes palettes.
struct PaletteListView: View {
    @Environment(PaletteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: ColorPalette?
    @State private var deleting: ColorPalette?

    var body: some View {
        List {
            ForEach(store.palettes) { palette in
                HStack(spacing: 14) {
                    Image(systemName: palette.id == store.selectedID ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(palette.id == store.selectedID ? Color.accentColor : .secondary)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(palette.displayName)
                            .font(.headline)
                        SwatchRow(colors: palette.uiColors)
                    }
                    Spacer()
                    if !palette.isStandard {
                        Button("Edit") { editing = palette }
                            .systemGlassButtonStyle()
                    }
                }
                .contentShape(.rect)
                .onTapGesture { store.selectedID = palette.id }
                .swipeActions {
                    if !palette.isStandard {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            deleting = palette
                        }
                    }
                }
                .contextMenu {
                    if !palette.isStandard {
                        Button("Edit", systemImage: "pencil") { editing = palette }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            deleting = palette
                        }
                    }
                }
            }
        }
        .navigationTitle("Palettes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Palette", systemImage: "plus") {
                    let palette = store.addPalette()
                    store.selectedID = palette.id
                    editing = palette
                }
            }
        }
        .sheet(item: $editing) { palette in
            PaletteEditor(palette: palette)
        }
        .confirmPaletteDeletion($deleting)
    }
}

extension View {
    /// Asks before deleting a palette; the standard one can never be deleted.
    func confirmPaletteDeletion(_ palette: Binding<ColorPalette?>, onDelete: @escaping () -> Void = {}) -> some View {
        modifier(PaletteDeletionDialog(palette: palette, onDelete: onDelete))
    }
}

private struct PaletteDeletionDialog: ViewModifier {
    @Binding var palette: ColorPalette?
    let onDelete: () -> Void
    @Environment(PaletteStore.self) private var store

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text("Delete “\(palette?.displayName ?? "")”?"),
            isPresented: Binding(get: { palette != nil }, set: { if !$0 { palette = nil } }),
            titleVisibility: .visible,
            presenting: palette
        ) { palette in
            Button("Delete Palette", role: .destructive) {
                store.delete(palette)
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Your writing keeps its colors. The Standard palette is used instead.")
        }
    }
}

struct SwatchRow: View {
    let colors: [UIColor]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(colors.indices, id: \.self) { index in
                Circle()
                    .fill(Color(uiColor: colors[index]))
                    .frame(width: 22, height: 22)
                    .overlay { Circle().strokeBorder(.primary.opacity(0.15), lineWidth: 1) }
            }
        }
    }
}

/// Edits the name and the 8 colors of a custom palette.
struct PaletteEditor: View {
    @Environment(PaletteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var palette: ColorPalette
    @State private var deleting: ColorPalette?

    init(palette: ColorPalette) {
        _palette = State(initialValue: palette)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $palette.name)
                }
                Section("Colors") {
                    ForEach(palette.colors.indices, id: \.self) { index in
                        ColorPicker(selection: colorBinding(index), supportsOpacity: false) {
                            Text("Color \(index + 1)")
                        }
                    }
                }
                if !palette.isStandard {
                    Section {
                        Button("Delete Palette", systemImage: "trash", role: .destructive) {
                            deleting = palette
                        }
                    }
                }
            }
            .confirmPaletteDeletion($deleting) { dismiss() }
            .navigationTitle(palette.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .systemConfirm) {
                        store.update(palette)
                        dismiss()
                    }
                }
            }
        }
    }

    private func colorBinding(_ index: Int) -> Binding<Color> {
        Binding {
            Color(uiColor: UIColor(hex: palette.colors[index]))
        } set: { color in
            palette.colors[index] = UIColor(color).hex
        }
    }
}
