import SwiftUI

/// 設定 → 単位セット: the sets of 単位パレット. Add, delete, reorder and edit; changes apply at once.
struct UnitSetsEditor: View {
    @ObservedObject var model: Model
    @State private var selection: String?
    @State private var confirmReset = false
    private let unitRows = ["units.general", "units.stroke", "units.type", "units.asian"]
    private let incrementRows = ["units.keyIncrement", "units.cornerRadius", "units.sizeIncrement", "units.baselineIncrement"]

    private var index: Int? { model.unitSets.firstIndex { $0.id == selection } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(L("sets.title")) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        List(selection: $selection) {
                            ForEach(model.unitSets) { set in Text(set.name.isEmpty ? L("sets.untitled") : set.name).tag(set.id) }
                                .onMove { model.unitSets.move(fromOffsets: $0, toOffset: $1) }
                        }
                        .frame(width: 180, height: 220)
                        HStack(spacing: 4) {
                            Button { add() } label: { ListButtonLabel(symbol: "plus") }.help(L("sets.add"))
                            Button { remove() } label: { ListButtonLabel(symbol: "minus") }.help(L("sets.remove")).disabled(index == nil || model.unitSets.count <= 1)
                            Button { move(-1) } label: { ListButtonLabel(symbol: "chevron.up") }.help(L("sets.up")).disabled((index ?? 0) == 0)
                            Button { move(1) } label: { ListButtonLabel(symbol: "chevron.down") }.help(L("sets.down")).disabled(index.map { $0 >= model.unitSets.count - 1 } ?? true)
                        }
                        .controlSize(.small)
                    }
                    if let index { editor(index) } else { Text(L("sets.choose")).foregroundColor(.secondary) }
                }
                HStack {
                    Button(L("sets.reset")) { confirmReset = true }
                    Spacer()
                }
                Text(L("sets.hint")).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { if selection == nil { selection = model.unitSets.first?.id } }
        .confirmationDialog(L("sets.resetConfirm"), isPresented: $confirmReset) {
            Button(L("sets.reset"), role: .destructive) { model.unitSets = UnitSet.defaults; selection = model.unitSets.first?.id }
        }
    }

    private func binding<T>(_ index: Int, _ path: WritableKeyPath<UnitSet, T>) -> Binding<T> {
        Binding(get: { model.unitSets[index][keyPath: path] }, set: { model.unitSets[index][keyPath: path] = $0 })
    }

    @ViewBuilder private func editor(_ index: Int) -> some View {
        let set = model.unitSets[index]
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
            GridRow {
                Text(L("sets.name")).foregroundColor(.secondary).fixedSize()
                TextField("", text: binding(index, \.name)).frame(width: 200)
            }
            GridRow { Text(L("units.title")).font(.system(size: 13, weight: .semibold)).gridCellColumns(2).padding(.top, 4) }
            ForEach(0..<4, id: \.self) { popup in
                GridRow {
                    Text(L(unitRows[popup])).foregroundColor(.secondary).fixedSize()
                    Picker("", selection: Binding(get: { model.unitSets[index].units[popup] }, set: { model.unitSets[index].units[popup] = $0 })) {
                        ForEach(UnitSettings.choices[popup], id: \.self) { code in Text(UnitSettings.label(code: code, popup: popup)).tag(code) }
                    }
                    .labelsHidden().fixedSize()
                }
            }
            GridRow { Text(L("sets.detailTitle")).font(.system(size: 13, weight: .semibold)).gridCellColumns(2).padding(.top, 4) }
            ForEach(0..<4, id: \.self) { row in
                GridRow {
                    Text(L(incrementRows[row])).foregroundColor(.secondary).fixedSize()
                    HStack(spacing: 4) {
                        TextField("", value: Binding(get: { model.unitSets[index].increments[row] }, set: { model.unitSets[index].increments[row] = max(0, $0) }),
                                  format: .number.precision(.fractionLength(0...3)))
                            .frame(width: 70).multilineTextAlignment(.trailing)
                        let popup = UnitSettings.incrementUnitIndex[row]
                        Text(UnitSettings.label(code: set.units[popup], popup: popup)).foregroundColor(.secondary)
                    }
                }
            }
            GridRow { Text(L("sets.otherTitle")).font(.system(size: 13, weight: .semibold)).gridCellColumns(2).padding(.top, 4) }
            GridRow {
                Text(L("sets.colorMode")).foregroundColor(.secondary).fixedSize()
                Picker("", selection: binding(index, \.colorMode)) {
                    Text(L("sets.keep")).tag(UnitSet.ColorMode?.none)
                    Text("CMYK").tag(UnitSet.ColorMode?.some(.cmyk))
                    Text("RGB").tag(UnitSet.ColorMode?.some(.rgb))
                }.labelsHidden().fixedSize()
            }
            GridRow {
                Text(L("sets.overprint")).foregroundColor(.secondary).fixedSize()
                Picker("", selection: binding(index, \.overprintPreview)) {
                    Text(L("sets.keep")).tag(Bool?.none)
                    Text(L("on")).tag(Bool?.some(true))
                    Text(L("off")).tag(Bool?.some(false))
                }.labelsHidden().fixedSize()
            }
            GridRow {
                Text(L("sets.resolution")).foregroundColor(.secondary).fixedSize()
                Picker("", selection: binding(index, \.rasterResolution)) {
                    Text(L("sets.keep")).tag(Int?.none)
                    Text(L("sets.res72")).tag(Int?.some(72))
                    Text(L("sets.res150")).tag(Int?.some(150))
                    Text(L("sets.res300")).tag(Int?.some(300))
                }.labelsHidden().fixedSize()
            }
            GridRow {
                Text(L("sets.snapToPixel")).foregroundColor(.secondary).fixedSize()
                Picker("", selection: binding(index, \.snapToPixel)) {
                    Text(L("sets.keep")).tag(Bool?.none)
                    Text(L("on")).tag(Bool?.some(true))
                    Text(L("off")).tag(Bool?.some(false))
                }.labelsHidden().fixedSize()
            }
            GridRow {
                Text(L("sets.grid")).foregroundColor(.secondary).fixedSize()
                HStack(spacing: 8) {
                    Picker("", selection: binding(index, \.gridMode)) {
                        Text(L("sets.keep")).tag(UnitSet.GridMode?.none)
                        Text(L("sets.gridMatchTop")).tag(UnitSet.GridMode?.some(.matchTop))
                        Text(L("sets.gridColor")).tag(UnitSet.GridMode?.some(.color))
                    }.labelsHidden().fixedSize()
                    if set.gridMode == .color {
                        ColorPicker("", selection: Binding(get: { Color(hex: model.unitSets[index].gridHex ?? "FFFFFF") },
                                                           set: { model.unitSets[index].gridHex = $0.hexString }), supportsOpacity: false)
                            .labelsHidden()
                        Text("#" + (set.gridHex ?? "FFFFFF")).font(.system(size: 11, design: .monospaced)).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func add() {
        var new = model.unitSets.first(where: { $0.id == selection }) ?? UnitSet.defaults[0]
        new.id = UUID().uuidString
        new.name = String(format: L("sets.copyName"), new.name)
        model.unitSets.append(new)
        selection = new.id
    }
    private func remove() {
        guard let index, model.unitSets.count > 1 else { return }
        model.unitSets.remove(at: index)
        selection = model.unitSets[min(index, model.unitSets.count - 1)].id
    }
    private func move(_ step: Int) {
        guard let index, model.unitSets.indices.contains(index + step) else { return }
        model.unitSets.swapAt(index, index + step)
    }
}

/// The symbols differ in height (＋ is taller than −), so each sits in the same box and the buttons line up.
struct ListButtonLabel: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol).font(.system(size: 11, weight: .medium)).frame(width: 16, height: 14)
    }
}

extension Color {
    init(hex: String) {
        let value = UInt32(hex, radix: 16) ?? 0xFFFFFF
        self.init(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
    /// RRGGBB in sRGB, as the color panel's hex field takes it.
    var hexString: String {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return String(format: "%02X%02X%02X", Int((color.redComponent * 255).rounded()), Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
    }
}
