import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class PastePalette: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct RowPaletteView: View {
    @ObservedObject var model: Model
    @State private var dropTarget: UUID?
    private var panel: NSWindow? { (NSApp.delegate as? AppDelegate)?.rowPalette }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: L("queueCount"), String(model.upcoming.count))).font(.headline)
                Spacer()
                Button(M("addSelection")) { model.addSelection(fromWindow: true) }
                Button(L("pasteAll")) { model.pasteFromWindow(.all, window: panel) }
                    .disabled(model.upcoming.isEmpty || model.pasting)
            }
            if model.upcoming.isEmpty {
                Text(String(format: M("emptyPalette"), model.addShortcut.label)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(model.upcoming.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 0) {
                                    HStack(spacing: 10) {
                                        Text("\(index + 1)").monospacedDigit().frame(width: 28)
                                            .foregroundColor(model.nextIndex == index ? .accentColor : .secondary)
                                        Text(item.text).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(10).contentShape(Rectangle())
                                    .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
                                    .onTapGesture(count: 2) {
                                        model.selected = index
                                        model.pasteFromWindow(.line(id: item.id, newline: false, keep: false), window: panel)
                                    }
                                    .onTapGesture { model.selected = index }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction { model.selected = index }
                                    .accessibilityAction(named: Text(M("pasteItem"))) {
                                        model.pasteFromWindow(.line(id: item.id, newline: false, keep: false), window: panel)
                                    }
                                    Button { model.toggleStar(index) } label: {
                                        Image(systemName: item.starred ? "star.fill" : "star")
                                            .foregroundColor(item.starred ? .orange : .secondary).frame(width: 32, height: 36)
                                    }.buttonStyle(.plain).accessibilityLabel(L(item.starred ? "unstar" : "star"))
                                }
                                .background(model.selected == index ? Color.accentColor.opacity(0.15) : Color(nsColor: index.isMultiple(of: 2) ? .textBackgroundColor : .controlBackgroundColor))
                                .overlay(alignment: .top) { if dropTarget == item.id { Rectangle().fill(Color.accentColor).frame(height: 2) } }
                                .onDrop(of: [UTType.plainText], isTargeted: Binding(get: { dropTarget == item.id }, set: { dropTarget = $0 ? item.id : nil })) { acceptDrop($0, before: item.id) }
                                .id(item.id)
                            }
                        }
                    }
                    .onChange(of: model.selected) { value in if let value { if model.upcoming.indices.contains(value) { proxy.scrollTo(model.upcoming[value].id) } } }
                }
            }
            if !model.upcoming.isEmpty {
                Text(M("dropEnd")).font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity).padding(5)
                    .onDrop(of: [UTType.plainText], isTargeted: nil) { acceptDrop($0, before: nil) }
            }
            Text(model.targetName.map { String(format: L("clickTarget"), $0) } ?? L("clickNoTarget"))
                .font(.caption).foregroundColor(.secondary).lineLimit(2)
            Text(model.status == L("ready") ? M("paletteHint") : model.status).font(.caption).foregroundColor(model.statusIsError ? .red : .secondary).lineLimit(2)
            HStack {
                Button(L("clear")) { model.clearQueue() }.disabled(model.upcoming.isEmpty)
                Button(L("restart")) { model.restart() }.disabled(!model.canRestart)
                Spacer()
                Button { model.moveSelected(-1) } label: { Image(systemName: "arrow.up") }.accessibilityLabel(M("moveUp"))
                    .disabled(model.selected == nil || model.selected == 0 || model.pasting)
                Button { model.moveSelected(1) } label: { Image(systemName: "arrow.down") }.accessibilityLabel(M("moveDown"))
                    .disabled(model.selected == nil || model.selected == model.upcoming.count - 1 || model.pasting)
            }
            DisclosureGroup(M("explanation")) { Text(M("paletteHint")).font(.caption).fixedSize(horizontal: false, vertical: true) }
        }.padding(12)
        .frame(minWidth: 380, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .background(Color(nsColor: AppSurface.color))
    }
    private func acceptDrop(_ providers: [NSItemProvider], before anchor: UUID?) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? String, let id = UUID(uuidString: text) else { return }
            DispatchQueue.main.async { model.moveSlot(id: id, before: anchor); dropTarget = nil }
        }
        return true
    }

}
