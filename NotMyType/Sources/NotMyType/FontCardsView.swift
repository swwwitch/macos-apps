import AppKit
import CoreText
import SwiftUI

/// Draw only cards near the viewport; use file descriptors so inactive fonts can be compared.
struct FontCardsView: View {
    @ObservedObject private var store = LibraryStore.shared
    @AppStorage(NameDisplay.key) private var nameDisplay = NameDisplay.localized.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flippingID: UUID?
    let families: [FontFamily]
    let sample: String
    let size: Double
    let cardScale: Double
    var isolated = false

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240 * cardScale), spacing: 12)], spacing: 12) {
                ForEach(families) { family in
                    ForEach(family.files) { file in
                        card(file, family: family)
                    }
                }
            }
            .padding(12)
        }
        .background {
            if !isolated {
                Button(L("カードフォーカス表示")) {
                    if let target = focusTarget { openFocus(target.file, family: target.family) }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(focusTarget == nil)
                .frame(width: 0, height: 0).opacity(0)
                .accessibilityHidden(true)
            }
        }
    }

    private var focusTarget: (file: FontFile, family: FontFamily)? {
        for family in families {
            if let file = family.files.first(where: { selected($0, family) }) { return (file, family) }
        }
        return nil
    }

    private func openFocus(_ file: FontFile, family: FontFamily) {
            let presentation = FontCardPresentation.shared
            guard !isolated, !presentation.opening, presentation.card == nil else { return }
            presentation.opening = true
            Task { @MainActor in
                if !reduceMotion {
                    withAnimation(.easeIn(duration: 0.15)) { flippingID = file.id }
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
                withAnimation(.easeOut(duration: 0.15)) {
                    presentation.card = FocusedFontCard(file: file, family: family, sample: sample, size: size, cardScale: cardScale)
                }
                try? await Task.sleep(nanoseconds: 180_000_000)
                flippingID = nil
                presentation.opening = false
            }
    }

    private func selected(_ file: FontFile, _ family: FontFamily) -> Bool {
        store.selection.contains(FamilyNode.fileID(file)) || store.selection.contains(family.id)
    }

    private func targets(_ file: FontFile, _ family: FontFamily) -> [FontFile] {
        !isolated && selected(file, family) ? store.selectedFiles : [file]
    }

    private func card(_ file: FontFile, family: FontFamily) -> some View {
        let mode = NameDisplay(rawValue: nameDisplay) ?? .localized
        let postScript = file.faces.map(\.postScriptName).joined(separator: L("、"))
        let title = mode == .postScript ? postScript : family.displayName
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: store.isActive(file) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(store.isActive(file) ? Color.accentColor : Color.secondary)
                Text(title).font(.headline).lineLimit(1).help(title)
                Spacer(minLength: 0)
            }
            if mode != .postScript {
                Text(file.faces.first?.style ?? file.fileName)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            if mode == .both {
                Text(postScript).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).help(postScript)
            }
            if let face = file.faces.first, let font = PreviewFonts.font(file: file, face: face, size: size) {
                Text(sample).font(Font(font)).lineLimit(3)
                    .frame(maxWidth: .infinity, minHeight: 110 * cardScale, maxHeight: 110 * cardScale, alignment: .topLeading)
                    .clipped()
            } else {
                Text(L("プレビューできません"))
                    .foregroundStyle(.secondary).frame(height: 110 * cardScale)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected(file, family) ? Color.accentColor.opacity(0.12) : Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected(file, family) ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected(file, family) ? 2 : 1))
        .contentShape(Rectangle())
        .rotation3DEffect(.degrees(flippingID == file.id ? 90 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .onTapGesture(count: 2) { openFocus(file, family: family) }
        .onTapGesture {
            let id = FamilyNode.fileID(file)
            if NSEvent.modifierFlags.contains(.command) {
                if store.selection.contains(id) { store.selection.remove(id) }
                else { store.selection.insert(id) }
            } else { store.selection = [id] }
        }
        .onDrag {
            let files = targets(file, family)
            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: FontMembershipDrag.type, visibility: .ownProcess) { completion in
                completion(FontMembershipDrag.encode(files.map(\.id)), nil)
                return nil
            }
            return provider
        }
        .contextMenu { menu(targets(file, family)) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected(file, family) ? .isSelected : [])
    }

    @ViewBuilder private func menu(_ files: [FontFile]) -> some View {
        let editable = files.filter { !LibraryStore.isLocked($0) }
        let deactivate = !editable.isEmpty && editable.allSatisfy { store.isActive($0) }
        Button(deactivate ? L("非アクティブにする") : L("アクティブにする")) { store.setActive(editable, !deactivate) }
            .disabled(editable.isEmpty || store.isBusy)
        Divider()
        let families = store.data.families(of: files)
        Toggle(L("お気に入り"), isOn: Binding(get: { families.allSatisfy { store.isFavorite($0) } }, set: { _ in store.toggleFavorite(families) }))
        Menu(L("セットに追加")) {
            ForEach(store.data.sets) { set in
                Toggle(set.name, isOn: Binding(get: { Set(files.map(\.id)).isSubset(of: Set(set.files)) }, set: { enabled in
                    if enabled { store.addToSet(set.id, files) } else { store.removeFromSet(set.id, files) }
                }))
            }
            Divider()
            Button(L("新規セット…")) { store.newSet(with: files) }
        }
        Menu(L("プロジェクトに追加")) {
            ForEach(store.data.projects) { project in
                Button(project.name) { store.addToProject(project.id, files) }
            }
            Divider()
            Button(L("新規プロジェクト…")) { store.newProject(with: files) }
        }
        Menu(L("コレクションに追加")) {
            ForEach(store.collectionNames, id: \.self) { name in
                Button(name) { store.addToCollection(name, files) }
            }
            Divider()
            Button(L("新規コレクション…")) { store.addToCollection(nil, files) }
        }
        Divider()
        if case .set(let id) = store.sidebar { Button(L("このセットから外す")) { store.removeFromSet(id, files) } }
        if case .project(let id) = store.sidebar { Button(L("プロジェクトから外す")) { store.removeFromProject(id, files) } }
        Button(L("ライブラリから取り除く…")) { store.remove(files) }
        Divider()
        Button(L("Finderで表示")) { store.revealInFinder(files) }
        if store.hasDuplicates(files) { Button(L("選んだフォントを優先にする")) { store.preferSelected(files) } }
    }
}
