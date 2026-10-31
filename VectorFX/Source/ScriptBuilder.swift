import Foundation

/// The ExtendScript sent to Illustrator with `do javascript`. Every built-in script returns "OK" or "ERR:<reason>".
enum ScriptBuilder {
    enum Failure: String { case nodoc, nosel, text, needtext, nostyle, action, file }

    static func quoteJS(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r") + "\""
    }
    /// Numbers written into the effect XML (no exponent, no locale).
    static func number(_ value: Double) -> String {
        let rounded = (value * 1_000_000).rounded() / 1_000_000
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.6f", rounded).replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
    }

    /// nil for script files (run as the file itself). `recorded` returns the text of a bundled .aia by name.
    static func source(for command: Command, values: [String: Double], dialog: Bool = false, recorded: (String) -> String? = { _ in nil }) -> String? {
        func value(_ key: String) -> Double { values[key] ?? command.params.first { $0.key == key }?.defaultValue ?? 0 }
        switch command.action {
        case .script:
            return nil
        case .menu(let id, _):
            return wrap("app.executeMenuCommand(\(quoteJS(id)));")
        case .effect(let kind):
            if dialog { return wrap("app.executeMenuCommand(\(quoteJS(kind.dialog)));") }
            return wrap(effectBody(kind, value))
        case .code(.cap(let cap)):
            return wrap(capFunction + "for (var k = 0; k < sel.length; k++) setCap(sel[k], StrokeCap.\(cap));")
        case .code(.flattenTransform):
            // One text frame: a rectangle 1 × 3 (document units) larger, flattened at its top and moved down by half the font size.
            return wrap(units + """
            if (!(sel.length === 1 && sel[0].typename === "TextFrame")) return "ERR:needtext";
            var size = sel[0].textRange.characterAttributes.size;
            sel[0].applyEffect(\(quoteJS(shapeXML)).replace("#W#", U(1)).replace("#H#", U(3)));
            sel[0].applyEffect(\(quoteJS(transformXML(pin: 1))).replace("#MV#", -size / 2));
            """)
        case .code(.openPath(let moveHalf)):
            // Text: a rectangle around it first (and, with moveHalf, the line half the font size down from the top).
            // Then height 0, Pathfinder Outline, and a 1 pt round-cap stroke (text) or round caps (paths).
            let stroke = recorded("strokeRound1pt").map { TempAction.renamed($0) } ?? ""
            return wrap(units + runActionFunction + capFunction + """
            var isText = sel[0].typename === "TextFrame";
            if (isText) {
                var size = sel[0].textRange.characterAttributes.size;
                for (var i = 0; i < sel.length; i++) {
                    sel[i].applyEffect(\(quoteJS(shapeXML)).replace("#W#", 0).replace("#H#", 0));
                    sel[i].applyEffect(\(quoteJS(transformXML(pin: moveHalf ? 1 : 4))).replace("#MV#", \(moveHalf ? "-size / 2" : "0")));
                }
            } else {
                for (var j = 0; j < sel.length; j++) sel[j].applyEffect(\(quoteJS(transformXML(pin: 4))).replace("#MV#", 0));
            }
            app.executeMenuCommand("Live Pathfinder Outline");
            if (isText) { runAction(\(quoteJS(stroke)), \(quoteJS(TempAction.setName)), \(quoteJS(TempAction.actionName))); }
            else { for (var k = 0; k < sel.length; k++) setCap(sel[k], StrokeCap.ROUNDENDCAP); }
            """)
        case .code(.resetFill(let white)):
            return wrap(runActionFunction + """
            runAction(\(quoteJS(TempAction.appearance(value: 6, name: "アピアランスを消去").source)), \(quoteJS(TempAction.setName)), \(quoteJS(TempAction.actionName)));
            var color;
            if (doc.documentColorSpace === DocumentColorSpace.CMYK) { color = new CMYKColor(); color.cyan = 0; color.magenta = 0; color.yellow = 0; color.black = \(white ? 0 : 100); }
            else { color = new RGBColor(); color.red = \(white ? 255 : 0); color.green = \(white ? 255 : 0); color.blue = \(white ? 255 : 0); }
            doc.defaultStroked = false;
            doc.defaultFillColor = color;
            for (var i = 0; i < sel.length; i++) sel[i].opacity = 100;
            """)
        case .code(.pasteLastStyle):
            return wrap("""
            var styles = doc.graphicStyles;
            if (styles.length === 0) return "ERR:nostyle";
            for (var i = 0; i < sel.length; i++) styles[styles.length - 1].applyTo(sel[i]);
            """)
        case .code(.expandUngroup):
            return wrap("app.executeMenuCommand(\"expandStyle\");\napp.executeMenuCommand(\"ungroup\");\napp.executeMenuCommand(\"deselectall\");")
        case .recordedAction(let name):
            guard let raw = recorded(name) else { return wrap("return \"ERR:file\";") }
            return wrap(runActionFunction + "runAction(\(quoteJS(TempAction.renamed(raw))), \(quoteJS(TempAction.setName)), \(quoteJS(TempAction.actionName)));")
        case .action(let action):
            return wrap(runActionFunction + "runAction(\(quoteJS(action.source)), \(quoteJS(TempAction.setName)), \(quoteJS(TempAction.actionName)));")
        case .namedAction(let set, let name):
            return wrap("try { app.doScript(\(quoteJS(name)), \(quoteJS(set)), false); } catch (e) { return \"ERR:action\"; }")
        }
    }

    /// Guards shared by the built-in scripts: an open document and objects (not text being edited) selected.
    static func wrap(_ body: String) -> String {
        """
        (function () {
        if (app.documents.length === 0) return "ERR:nodoc";
        var doc = app.activeDocument;
        var sel = doc.selection;
        if (!sel) return "ERR:nosel";
        if (sel.typename === "TextRange") return "ERR:text";
        if (sel.length === 0) return "ERR:nosel";
        \(body)
        return "OK";
        })();
        """
    }

    /// Sets the cap of paths, also inside groups and compound paths.
    static let capFunction = """
    function setCap(item, cap) {
        if (item.typename === "GroupItem") { for (var i = 0; i < item.pageItems.length; i++) setCap(item.pageItems[i], cap); }
        else if (item.typename === "CompoundPathItem") { for (var j = 0; j < item.pathItems.length; j++) setCap(item.pathItems[j], cap); }
        else if (item.typename === "PathItem" && item.stroked) { item.strokeCap = cap; }
    }

    """

    /// U(v): document units → points, like typing the value into an effect dialog box.
    static let units = """
    function U(v) {
        var r = doc.rulerUnits, f = 1;
        if (r === RulerUnits.Millimeters) f = 72 / 25.4;
        else if (r === RulerUnits.Centimeters) f = 72 / 2.54;
        else if (r === RulerUnits.Inches) f = 72;
        else if (r === RulerUnits.Picas) f = 12;
        else if (r === RulerUnits.Qs) f = 72 / 25.4 / 4;
        return v * f;
    }

    """

    static let shapeXML = shapeXML(shape: 0, name: "Rectangle")
    /// Convert to Shape, relative size (extra width #W# / height #H#, points). Shape 0 rectangle, 1 rounded rectangle, 2 ellipse.
    static func shapeXML(shape: Int, name: String, radius: String = "9") -> String {
        "<LiveEffect name=\"Adobe Shape Effects\" isPre=\"1\"><Dict data=\"U DisplayString \(name) I Shape \(shape) R RelWidth #W# R RelHeight #H# R AbsWidth 0 R AbsHeight 0 R Absolute 0 R CornerRadius \(radius) \"/></LiveEffect>"
    }

    /// Height 0 %, moved #MV# points (negative = down); pin 1 top center, 4 center.
    static func transformXML(pin: Int) -> String {
        "<LiveEffect name=\"Adobe Transform\"><Dict data=\"R scaleH_Percent 100 R scaleV_Percent 0 R scaleH_Factor 1 R scaleV_Factor 0 R moveH_Pts 0 R moveV_Pts #MV# R rotate_Degrees 0 R rotate_Radians 0 I numCopies 0 I pinPoint \(pin) B scaleLines 1 B transformPatterns 1 B transformObjects 1 B reflectX 0 B reflectY 0 B randomize 0 \"/></LiveEffect>"
    }

    private static func effectBody(_ kind: EffectKind, _ value: (String) -> Double) -> String {
        let xml: String
        switch kind {
        case .dropShadow:
            // Multiply, black. Opacity is 0–1 in the Dict; offsets and blur in points.
            xml = "<LiveEffect name=\"Adobe Drop Shadow\"><Dict data=\"I blnd 1 R opac \(number(value("opacity") / 100)) R horz #X# R vert #Y# R blur #B# B usePSLBlur 1 I csrc 0 R dark 100 B pair 1 \"><Entry name=\"sclr\" valueType=\"F\"><Fill color=\"#C#\"/></Entry></Dict></LiveEffect>"
            return units + """
            var xml = \(quoteJS(xml)).replace("#X#", U(\(number(value("offsetX"))))).replace("#Y#", U(\(number(value("offsetY"))))).replace("#B#", U(\(number(value("blur")))))
                .replace("#C#", doc.documentColorSpace === DocumentColorSpace.CMYK ? "0 0 0 1" : "0 0 0");
            for (var i = 0; i < sel.length; i++) sel[i].applyEffect(xml);
            """
        case .offsetPath:
            xml = "<LiveEffect name=\"Adobe Offset Path\"><Dict data=\"R ofst #O# I jntp \(Int(value("join"))) R mlim 4 \"/></LiveEffect>"
            return units + "var xml = \(quoteJS(xml)).replace(\"#O#\", U(\(number(value("offset")))));\nfor (var i = 0; i < sel.length; i++) sel[i].applyEffect(xml);"
        case .rectangle, .roundedRectangle, .ellipse:
            let xml = kind == .ellipse ? shapeXML(shape: 2, name: "Ellipse") : kind == .roundedRectangle ? shapeXML(shape: 1, name: "Rounded Rectangle", radius: "#R#") : shapeXML
            return units + "var xml = \(quoteJS(xml)).replace(\"#R#\", U(\(number(value("cornerRadius"))))).replace(\"#W#\", U(\(number(value("extraWidth"))))).replace(\"#H#\", U(\(number(value("extraHeight")))));\nfor (var i = 0; i < sel.length; i++) sel[i].applyEffect(xml);"
        case .zigzag:
            xml = "<LiveEffect name=\"Adobe Zigzag\"><Dict data=\"R amount #A# R relAmount 0 R absoluteness 1 R ridges \(Int(value("ridges"))) R roundness \(value("smooth") != 0 ? 1 : 0) \"/></LiveEffect>"
            return units + "var xml = \(quoteJS(xml)).replace(\"#A#\", U(\(number(value("size")))));\nfor (var i = 0; i < sel.length; i++) sel[i].applyEffect(xml);"
        case .roughen:
            xml = "<LiveEffect name=\"Adobe Roughen\"><Dict data=\"R asiz #S# R size 0 R absoluteness 1 R dtal \(number(value("detail"))) R roundness \(value("smooth") != 0 ? 1 : 0) \"/></LiveEffect>"
            return units + "var xml = \(quoteJS(xml)).replace(\"#S#\", U(\(number(value("size")))));\nfor (var i = 0; i < sel.length; i++) sel[i].applyEffect(xml);"
        }
    }

    /// Writes the action to a temporary .aia, loads it, plays it and unloads it again (also after an error).
    static let runActionFunction = """
    function runAction(code, setName, actionName) {
        var file = new File(Folder.temp + "/VectorFX-temp-action.aia");
        file.open("w"); file.write(code); file.close();
        try { app.unloadAction(setName, ""); } catch (e0) {}
        var loaded = false;
        try {
            app.loadAction(file); loaded = true;
            app.doScript(actionName, setName, false);
        } finally {
            if (loaded) { try { app.unloadAction(setName, ""); } catch (e1) {} }
            file.remove();
        }
    }

    """
}
