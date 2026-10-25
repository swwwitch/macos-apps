import AppKit
import SwiftUI

enum DetailTab: String, CaseIterable { case before, after, documents }

struct MainView: View {
    @ObservedObject var model: Model
    @ObservedObject var library: Library
    @AppStorage("detailTab") private var tab = DetailTab.before.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(nsImage: currentAppIcon()).resizable().frame(width: 52, height: 52).accessibilityHidden(true)
                    AppVersionLabel()
                }
                VStack(alignment: .leading, spacing: 4) { Text(L("heading")).font(.system(size: 22, weight: .semibold)); Text(L("subtitle")).foregroundStyle(.secondary) }
                Spacer()
            }
            HStack(alignment: .top, spacing: 14) {
                sidebar.frame(width: 300)
                detail.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            HStack {
                Text(statusText.isEmpty ? " " : statusText).font(.callout).foregroundColor(model.statusIsError || !library.saveError.isEmpty ? .red : .secondary).lineLimit(2)
                Spacer()
                if model.working { ProgressView().controlSize(.small) }
            }
        }
        .padding(20)
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: AppSurface.color)).tint(appTint)
    }
    private var statusText: String { library.saveError.isEmpty ? model.status : library.saveError }

    // MARK: Event list

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(format: L("events"), library.events.count)).font(.headline)
                Spacer()
            }
            TextField(L("searchPlaceholder"), text: $library.search).textFieldStyle(.roundedBorder).accessibilityLabel(L("search"))
            List(selection: $library.selection) {
                ForEach(library.filtered) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("#" + event.record["#"]).font(.caption).monospacedDigit().foregroundColor(.secondary)
                            Text(shortDate(event.record["仮の日付"])).font(.caption).monospacedDigit().foregroundColor(.secondary)
                            Text(event.record["種別"]).font(.caption).foregroundColor(appTint)
                            if event.url?.lastPathComponent != EventRecord.fileName {
                                Image(systemName: "folder.badge.questionmark").font(.caption).foregroundColor(.secondary)
                                    .help(L("noFolderYet")).accessibilityLabel(L("noFolderYet"))
                            }
                        }
                        Text(event.record.displayName).lineLimit(2)
                    }.tag(event.id).padding(.vertical, 2)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.25)))
            HStack(spacing: 6) {
                Button { library.newEvent() } label: { Image(systemName: "plus") }.help(L("newEvent")).accessibilityLabel(L("newEvent"))
                Button { library.deleteCurrent() } label: { Image(systemName: "minus") }.disabled(library.current == nil).help(L("deleteEvent")).accessibilityLabel(L("deleteEvent"))
                Button { library.duplicate() } label: { Image(systemName: "plus.square.on.square") }.disabled(library.current == nil).help(L("duplicateEvent")).accessibilityLabel(L("duplicateEvent"))
                Spacer()
                Button(L("importSheet")) { model.importSheet() }.disabled(model.working)
            }
        }
    }
    private func shortDate(_ compact: String) -> String {
        guard compact.count == 8, Int(compact) != nil else { return compact }
        let chars = Array(compact)
        return String(chars[0..<4]) + "/" + String(chars[4..<6]) + "/" + String(chars[6..<8])
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if let record = library.current {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.displayName).font(.title3.weight(.semibold)).lineLimit(2).textSelection(.enabled)
                    Text(record.folderName.map { displayPath(model.root) + "/" + $0 } ?? L("folderNeeds"))
                        .font(.caption).foregroundColor(record.folderName == nil ? .orange : .secondary).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                }
                Picker("", selection: $tab) {
                    Text(L("tab.before")).tag(DetailTab.before.rawValue)
                    Text(L("tab.after")).tag(DetailTab.after.rawValue)
                    Text(L("tab.documents")).tag(DetailTab.documents.rawValue)
                }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 420)
                switch DetailTab(rawValue: tab) ?? .before {
                case .before: form(groups: Schema.groupsBefore, tab: .before)
                case .after: form(groups: Schema.groupsAfter, tab: .after)
                case .documents: DocumentsPane(model: model, library: library)
                }
            }
            .id(record.id)
        } else {
            VStack(spacing: 12) {
                Text(L("noEvent")).foregroundColor(.secondary)
                HStack {
                    Button(L("newEvent")) { library.newEvent() }
                    Button(L("importSheet")) { model.importSheet() }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func form(groups: [String], tab: Field.Tab) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(groups, id: \.self) { group in
                    let fields = Schema.fields.filter { $0.tab == tab && $0.group == group }
                    if !fields.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L("group." + group)).font(.headline)
                            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 6) {
                                ForEach(fields) { field in
                                    GridRow {
                                        Text(field.key).font(.callout).foregroundColor(.secondary).frame(width: 210, alignment: .trailing).gridColumnAlignment(.trailing)
                                        FieldInput(field: field, library: library)
                                    }
                                }
                            }
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor)).cornerRadius(8)
                    }
                }
            }.padding(.trailing, 8)
        }
    }
}

struct FieldInput: View {
    let field: Field
    @ObservedObject var library: Library
    private var text: Binding<String> { Binding(get: { library.value(field.key) }, set: { library.setValue(field.key, $0) }) }
    private var hint: String {
        switch field.kind {
        case .compactDate: return "20261231"
        case .isoDate: return "2026-12-31"
        case .time: return "21:00"
        default: return ""
        }
    }
    var body: some View {
        Group {
            if field.kind == .multiline {
                TextField(hint, text: text, axis: .vertical).lineLimit(3...12)
            } else {
                TextField(hint, text: text)
            }
        }
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(field.key)
    }
}

/// Making the documents for the selected event: summary, options, result and the variables.
struct DocumentsPane: View {
    @ObservedObject var model: Model
    @ObservedObject var library: Library
    @State private var showVariables = false

    var body: some View {
        let event = model.variables
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 4) {
                    row("summary.category", event["EventCategory"])
                    row("summary.name", event["EventName"])
                    row("summary.date", event["EventDate"])
                    GridRow {
                        Text(L("summary.folder")).foregroundColor(.secondary).gridColumnAlignment(.trailing)
                        if event.missingRequired.isEmpty {
                            Text(displayPath(model.root) + "/" + event["EventPath"]).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                        } else {
                            Text(String(format: L("summary.missing"), event.missingRequired.joined(separator: L("listSeparator")))).foregroundColor(.orange)
                        }
                    }
                    row("summary.templates", String(format: L("summary.templateCount"), model.templateCount))
                }.font(.callout)
                HStack(spacing: 16) {
                    Toggle(L("makeQR"), isOn: $model.makeQR)
                    Toggle(L("openAfter"), isOn: $model.openAfter)
                    Spacer()
                    Button(L("generate")) { model.generate() }.keyboardShortcut(.return, modifiers: .command).disabled(!model.canGenerate)
                }
                if let result = model.result, model.resultEvent == library.selection { resultView(result) }
                DisclosureGroup(isExpanded: $showVariables) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(event.vars.keys.sorted(), id: \.self) { name in
                            HStack(alignment: .firstTextBaseline) {
                                Text(name).font(.system(size: 11, design: .monospaced)).frame(width: 260, alignment: .leading).textSelection(.enabled)
                                Text(event[name].replacingOccurrences(of: "\n", with: "⏎")).font(.caption).foregroundColor(.secondary).lineLimit(1).textSelection(.enabled)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                } label: { Text(String(format: L("variables"), event.vars.count)) }
            }.padding(.trailing, 8)
        }
    }
    private func row(_ key: String, _ value: String) -> some View {
        GridRow { Text(L(key)).foregroundColor(.secondary); Text(value.isEmpty || value == "-" ? "—" : value).lineLimit(1) }
    }
    private func resultView(_ result: GenerationResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(String(format: L("result.written"), result.written.count), systemImage: "checkmark.circle.fill").foregroundColor(.green)
                Spacer()
                Button(L("result.open")) { model.open(result.folder.appendingPathComponent("docs")) }
            }
            if !result.qrCodes.isEmpty { Text(String(format: L("result.qr"), result.qrCodes.count)).font(.caption) }
            if let copy = result.storesCopy { Text(String(format: L("result.stores"), copy)).font(.caption) }
            if !result.emptyVariables.isEmpty {
                Text(String(format: L("result.empty"), result.emptyVariables.count, result.emptyVariables.prefix(12).joined(separator: " ")))
                    .font(.caption).foregroundColor(.secondary).lineLimit(3).textSelection(.enabled)
            }
            ForEach(result.warnings, id: \.self) { Text($0).font(.caption).foregroundColor(.orange) }
        }
        .padding(10).background(Color(nsColor: .textBackgroundColor)).cornerRadius(8)
    }
}
