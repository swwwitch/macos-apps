// CarmaChameleon (.ai → PNG / SVG): export each chosen artboard through Export for Screens.
// Each artboard goes into its own subfolder "ab<number>" so the app can pair every file with its artboard.
// Like SaveAsPDF.jsx, exporting never changes the document's file, so a document already open stays open.
// arguments: [inputPath, outputFolder, kind ("png" | "svg"), range ("" = all, "1,3-5"), ppi, transparent ("1" | "0"),
//             css, font, images, precision, idType, minify ("1" | "0"), responsive ("1" | "0")]
// Returns "OK" plus tab-separated notes ("open", "unsaved", "links"), then one line per artboard
// "AB\t<number>\t<name>" (after "COUNT\t<artboards in the document>"), or "ERROR:<reason>" (tooOld, range, rangeOut\t<count>, or a message).
(function (args) {
    var input = new File(args[0]), folder = new Folder(args[1]), kind = args[2], range = args[3];
    if (Number(app.version.split(".")[0]) < 22) return "ERROR:tooOld"; // exportForScreens needs CC 2018+

    /* "1,3-5" → [1,3,4,5]; same rules as PageRange.parse in the app */
    function parseRange(text, count) {
        var spec = String(text).replace(/\s/g, "").replace(/[，、]/g, ",").replace(/[〜～–]/g, "-");
        var list = [], i, n;
        if (spec === "") { for (i = 1; i <= count; i++) list.push(i); return list; }
        var tokens = spec.split(",");
        for (var t = 0; t < tokens.length; t++) {
            if (tokens[t] === "") continue;
            var m = tokens[t].match(/^(\d+)(?:-(\d*))?$/);
            if (!m) throw "range";
            var a = Number(m[1]), b = (m[2] === undefined || m[2] === "") ? (tokens[t].indexOf("-") > 0 ? count : a) : Number(m[2]);
            if (a > b) throw "range";
            if (a < 1 || b > count) throw "rangeOut";
            for (n = a; n <= b; n++) {
                var seen = false;
                for (i = 0; i < list.length; i++) if (list[i] === n) seen = true;
                if (!seen) list.push(n);
            }
        }
        if (list.length === 0) throw "range";
        return list;
    }

    var prefs = app.preferences, folderKey = "plugin/SmartExportUI/CreateFoldersPreference";
    var level = app.userInteractionLevel, createFolders = prefs.getBooleanPreference(folderKey);
    var doc = null, opened = false, notes = [];
    app.userInteractionLevel = UserInteractionLevel.DONTDISPLAYALERTS; // missing fonts / links must not block
    try {
        // Opening a file that is already open only brings it to the front; the document count tells which it was
        // (comparing paths can miss with Japanese names and would close the user's document unsaved).
        var countBefore = app.documents.length;
        doc = app.open(input);
        opened = app.documents.length > countBefore;
        if (!opened) { notes.push("open"); if (!doc.saved) notes.push("unsaved"); }
        for (var k = 0; k < doc.placedItems.length; k++) {
            try { doc.placedItems[k].file; } catch (e) { notes.push("links"); break; }
        }
        var numbers;
        try { numbers = parseRange(range, doc.artboards.length); }
        catch (r) { return r === "rangeOut" ? "ERROR:rangeOut\t" + doc.artboards.length : "ERROR:range"; }

        var options, type;
        if (kind === "svg") {
            options = new ExportForScreensOptionsWebOptimizedSVG();
            options.cssProperties = SVGCSSPropertyLocation[args[6]];
            options.fontType = SVGFontType[args[7]];
            options.rasterImageLocation = RasterImageLocation[args[8]];
            options.coordinatePrecision = Number(args[9]);
            options.svgId = SVGIdType[args[10]];
            options.svgMinify = args[11] === "1";
            options.svgResponsive = args[12] === "1";
            type = ExportForScreensType.SE_SVG;
        } else {
            options = new ExportForScreensOptionsPNG24();
            options.scaleType = ExportForScreensScaleType.SCALEBYRESOLUTION;
            options.scaleTypeValue = Number(args[4]);
            options.transparency = args[5] === "1";
            type = ExportForScreensType.SE_PNG24;
        }
        prefs.setBooleanPreference(folderKey, false); // no "1x" / "SVG" subfolder
        var lines = [["OK"].concat(notes).join("\t"), "COUNT\t" + doc.artboards.length];
        for (var a = 0; a < numbers.length; a++) {
            var sub = new Folder(folder.fsName + "/ab" + numbers[a]);
            sub.create();
            var target = new ExportForScreensItemToExport();
            target.document = false;
            target.artboards = String(numbers[a]);
            doc.exportForScreens(sub, type, options, target);
            lines.push(["AB", numbers[a], doc.artboards[numbers[a] - 1].name.replace(/[\t\r\n]/g, " ")].join("\t"));
        }
        return lines.join("\n");
    } catch (e) {
        return "ERROR:" + (e.message || e);
    } finally {
        prefs.setBooleanPreference(folderKey, createFolders);
        if (doc && opened) { try { doc.close(SaveOptions.DONOTSAVECHANGES); } catch (e2) {} }
        app.userInteractionLevel = level;
    }
})(arguments);
