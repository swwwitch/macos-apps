import Foundation

/// Portable text-only IDML: A4 pages with editable text frames, independent of InDesign installation.
enum IDMLExporter {
    static let ns = "http://ns.adobe.com/AdobeInDesign/idml/1.0/packaging"
    static func write(text:String,to output:URL,in workspace:URL,cancelled:() -> Bool) throws {
        guard text.utf8.count <= 20*1024*1024 else { throw IDMLImporter.error("idmlTooLarge") }
        let package = workspace.appendingPathComponent("idml-package",isDirectory:true)
        let fm = FileManager.default
        for name in ["Stories","Spreads","Resources","META-INF"] { try fm.createDirectory(at:package.appendingPathComponent(name),withIntermediateDirectories:true) }
        func save(_ name:String,_ body:String) throws { try body.write(to:package.appendingPathComponent(name),atomically:true,encoding:.utf8) }
        func xml(_ body:String) -> String { "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" + body }
        let scalars = text.unicodeScalars.filter { $0.value == 9 || $0.value == 10 || $0.value == 13 || ($0.value >= 32 && $0.value != 0xFFFE && $0.value != 0xFFFF) }
        let clean = String(String.UnicodeScalarView(scalars)).replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n").replacingOccurrences(of:"\t",with:"    ")
        guard !clean.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw IDMLImporter.error("idmlNoText") }
        // Conservative fixed line lengths keep Japanese text inside the frame. Original styling is intentionally flattened.
        var lines: [String] = []
        for paragraph in clean.components(separatedBy:"\n") {
            var line = ""; var count = 0
            for character in paragraph {
                if count == 42 { lines.append(line); line = ""; count = 0 }
                line.append(character); count += 1
            }
            lines.append(line)
        }
        let pages = (lines.count+39)/40
        guard pages <= 500 else { throw IDMLImporter.error("idmlTooLarge") }
        var references = ""
        for index in 0..<pages {
            if cancelled() { throw CancellationError() }
            let id = index+1
            let content = lines[(index*40)..<min(lines.count,(index+1)*40)].map { "<Content>\(IDMLImporter.escape($0))</Content><Br/>" }.joined()
            let story = "<idPkg:Story xmlns:idPkg=\"\(ns)\" DOMVersion=\"8.0\"><Story Self=\"story\(id)\"><ParagraphStyleRange AppliedParagraphStyle=\"ParagraphStyle/Body\"><CharacterStyleRange AppliedCharacterStyle=\"CharacterStyle/Normal\" FontStyle=\"W3\" PointSize=\"10\"><Properties><AppliedFont type=\"string\">Hiragino Sans</AppliedFont><Leading type=\"unit\">16</Leading></Properties>\(content)</CharacterStyleRange></ParagraphStyleRange></Story></idPkg:Story>"
            try save("Stories/Story_\(id).xml",xml(story))
            let points = ["48 48","48 794","547 794","547 48"].map { "<PathPoint Anchor=\"\($0)\" LeftDirection=\"\($0)\" RightDirection=\"\($0)\"/>" }.joined()
            let spread = """
            <idPkg:Spread xmlns:idPkg="\(ns)" DOMVersion="8.0"><Spread Self="spread\(id)" PageCount="1" BindingLocation="0" AllowPageShuffle="false" ItemTransform="1 0 0 1 0 0"><Page Self="page\(id)" Name="\(id)" GeometricBounds="0 0 842 595" ItemTransform="1 0 0 1 0 0" AppliedMaster="n"/><TextFrame Self="frame\(id)" ParentStory="story\(id)" ContentType="TextType" ItemLayer="layer1" ItemTransform="1 0 0 1 0 0" PreviousTextFrame="n" NextTextFrame="n"><Properties><PathGeometry><GeometryPath PathOpen="false"><PathPointArray>\(points)</PathPointArray></GeometryPath></PathGeometry></Properties><TextFramePreference TextColumnCount="1" TextColumnFixedWidth="499"/></TextFrame></Spread></idPkg:Spread>
            """
            try save("Spreads/Spread_\(id).xml",xml(spread))
            references += "<idPkg:Spread src=\"Spreads/Spread_\(id).xml\"/><idPkg:Story src=\"Stories/Story_\(id).xml\"/>"
        }
        try save("Resources/Styles.xml",xml("<idPkg:Styles xmlns:idPkg=\"\(ns)\" DOMVersion=\"8.0\"><RootParagraphStyleGroup Self=\"paragraphs\"><ParagraphStyle Self=\"ParagraphStyle/Body\" Name=\"Body\" PointSize=\"10\"/></RootParagraphStyleGroup><RootCharacterStyleGroup Self=\"characters\"><CharacterStyle Self=\"CharacterStyle/Normal\" Name=\"Normal\"/></RootCharacterStyleGroup></idPkg:Styles>"))
        try save("designmap.xml",xml("<?aid style=\"50\" type=\"document\" readerVersion=\"6.0\" featureSet=\"257\"?><Document xmlns:idPkg=\"\(ns)\" DOMVersion=\"8.0\" Self=\"document1\"><Layer Self=\"layer1\" Name=\"Text\" Visible=\"true\" Printable=\"true\"/><DocumentPreference PageHeight=\"842\" PageWidth=\"595\" FacingPages=\"false\"/><idPkg:Styles src=\"Resources/Styles.xml\"/>\(references)</Document>"))
        try save("mimetype","application/vnd.adobe.indesign-idml-package")
        try save("META-INF/container.xml",xml("<container version=\"1.0\"><rootfiles><rootfile full-path=\"designmap.xml\" media-type=\"text/xml\"/></rootfiles></container>"))
        for args in [["-q","-X","-0",output.path,"mimetype"],["-q","-X","-r",output.path,"designmap.xml","META-INF","Resources","Spreads","Stories"]] {
            if cancelled() { throw CancellationError() }
            let p = Process(); p.executableURL = URL(fileURLWithPath:"/usr/bin/zip"); p.arguments = args; p.currentDirectoryURL = package
            p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice; try p.run(); p.waitUntilExit()
            guard p.terminationStatus == 0 else { throw IDMLImporter.error("idmlExportFailed") }
        }
        if cancelled() { throw CancellationError() }
    }
}
