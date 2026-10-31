import AppKit
import SwiftUI

final class PastePalette: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct RowPaletteView: View {
    @ObservedObject var model: Model
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
                            ForEach(Array(model.upcoming.enumerated()), id: \.offset) { index, item in
                                HStack(spacing: 0) {
                                    HStack(spacing: 10) {
                                        Text("\(index + 1)").monospacedDigit().frame(width: 28)
                                            .foregroundColor(model.nextIndex == index ? .accentColor : .secondary)
                                        Text(item.text).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(10).contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        model.selected = index
                                        model.pasteFromWindow(.line(index: index, text: item.text, newline: false, keep: false), window: panel)
                                    }
                                    .onTapGesture { model.selected = index }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction { model.selected = index }
                                    .accessibilityAction(named: Text(M("pasteItem"))) {
                                        model.pasteFromWindow(.line(index: index, text: item.text, newline: false, keep: false), window: panel)
                                    }
                                    Button { model.toggleStar(index) } label: {
                                        Image(systemName: item.starred ? "star.fill" : "star")
                                            .foregroundColor(item.starred ? .orange : .secondary).frame(width: 32, height: 36)
                                    }.buttonStyle(.plain).accessibilityLabel(L(item.starred ? "unstar" : "star"))
                                }
                                .background(model.selected == index ? Color.accentColor.opacity(0.15) : Color(nsColor: index.isMultiple(of: 2) ? .textBackgroundColor : .controlBackgroundColor))
                                .id(index)
                            }
                        }
                    }
                    .onChange(of: model.selected) { value in if let value { proxy.scrollTo(value) } }
                }
            }
            Text(model.targetName.map { String(format: L("clickTarget"), $0) } ?? L("clickNoTarget"))
                .font(.caption).foregroundColor(.secondary).lineLimit(2)
            Text(model.status == L("ready") ? M("paletteHint") : model.status).font(.caption).foregroundColor(model.statusIsError ? .red : .secondary).lineLimit(2)
            HStack {
                Button(L("clear")) { model.clearQueue() }.disabled(model.upcoming.isEmpty)
                Button(L("restart")) { model.restart() }.disabled(!model.canRestart)
                Spacer()
                DisclosureGroup(M("explanation")) { Text(M("paletteHint")).font(.caption).fixedSize(horizontal: false, vertical: true) }
                    .frame(maxWidth: 220)
            }
        }.padding(12)
        .frame(minWidth: 380, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .background(Color(nsColor: AppSurface.color))
    }
}
