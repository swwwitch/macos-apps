// CarmaChameleon (.indd → PDF / PNG): InDesign exports the document. Exporting never changes the document's file,
// so a document already open stays open. PNG: one page at a time into "p<number>" subfolders.
// arguments: [inputPath, outputFolder, kind ("pdf" | "png"), range ("" = all, "1,3-5"), sizeMode ("ppi" | "width" | "height"),
//             sizeValue, transparent ("1" | "0"), pdfPreset ("" = current PDF export settings)]
// Returns "OK" plus tab-separated notes ("open", "unsaved", "links"), then "COUNT\t<pages>" and one line per page
// "PG\t<number>\t<page name>", or "ERROR:<reason>" (presetMissing, range, rangeOut\t<count>, or a message).
(function (args) {
    var input = new File(args[0]), folder = new Folder(args[1]), kind = args[2], range = args[3];
    var sizeMode = args[4], sizeValue = Number(args[5]), transparent = args[6] === "1", presetName = args[7] || "";

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
            var a = Number(m[1]), b = a;                          // no nested ?: (ExtendScript gets it wrong)
            if (m[2] !== undefined && m[2] !== "") b = Number(m[2]);
            else if (tokens[t].indexOf("-") > 0) b = count;       // "3-" = to the end
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

    var preset = null;
    if (kind === "pdf" && presetName) {
        preset = app.pdfExportPresets.itemByName(presetName);
        if (!preset.isValid) return "ERROR:presetMissing";
    }
    var scriptPrefs = app.scriptPreferences, level = scriptPrefs.userInteractionLevel, unit = scriptPrefs.measurementUnit;
    // PNG export settings are application preferences: remember what is changed and put it back.
    var png = app.pngExportPreferences, pngKeys = ["pngExportRange", "pageString", "exportResolution", "transparentBackground", "antiAlias", "pngQuality", "exportingSpread", "useDocumentBleeds"];
    var pngSaved = {};
    for (var s = 0; s < pngKeys.length; s++) { try { pngSaved[pngKeys[s]] = png[pngKeys[s]]; } catch (e0) {} }
    var doc = null, opened = false, notes = [];
    scriptPrefs.userInteractionLevel = UserInteractionLevels.NEVER_INTERACT; // missing fonts / links must not block
    scriptPrefs.measurementUnit = MeasurementUnits.POINTS;                  // page bounds in points (script only)
    try {
        // Opening a file that is already open returns that document; the document count tells which it was.
        var countBefore = app.documents.length;
        doc = app.open(input, false);
        opened = app.documents.length > countBefore;
        if (!opened) { notes.push("open"); if (doc.modified) notes.push("unsaved"); }
        for (var k = 0; k < doc.links.length; k++) {
            if (doc.links[k].status === LinkStatus.LINK_MISSING) { notes.push("links"); break; }
        }
        var lines = [["OK"].concat(notes).join("\t"), "COUNT\t" + doc.pages.length];
        if (kind === "pdf") {
            var pdf = new File(folder.fsName + "/result.pdf");
            if (preset) doc.exportFile(ExportFormat.PDF_TYPE, pdf, false, preset);
            else doc.exportFile(ExportFormat.PDF_TYPE, pdf, false);
            return lines.join("\n");
        }
        var numbers;
        try { numbers = parseRange(range, doc.pages.length); }
        catch (r) { return r === "rangeOut" ? "ERROR:rangeOut\t" + doc.pages.length : "ERROR:range"; }
        png.pngExportRange = PNGExportRangeEnum.EXPORT_RANGE;
        png.transparentBackground = transparent;
        png.antiAlias = true;
        png.pngQuality = PNGQualityEnum.MAXIMUM;
        png.exportingSpread = false;
        png.useDocumentBleeds = false;
        for (var p = 0; p < numbers.length; p++) {
            var page = doc.pages[numbers[p] - 1], b = page.bounds; // [top, left, bottom, right]
            var ppi = sizeValue;
            if (sizeMode === "width") ppi = sizeValue * 72 / (b[3] - b[1]);
            if (sizeMode === "height") ppi = sizeValue * 72 / (b[2] - b[0]);
            png.exportResolution = Math.max(1, Math.min(2400, ppi));
            png.pageString = "+" + numbers[p]; // absolute page number, independent of section numbering
            var sub = new Folder(folder.fsName + "/p" + numbers[p]);
            sub.create();
            doc.exportFile(ExportFormat.PNG_FORMAT, new File(sub.fsName + "/page.png"), false);
            lines.push(["PG", numbers[p], String(page.name).replace(/[\t\r\n]/g, " ")].join("\t"));
        }
        return lines.join("\n");
    } catch (e) {
        return "ERROR:" + (e.message || e);
    } finally {
        for (var key in pngSaved) { try { png[key] = pngSaved[key]; } catch (e1) {} }
        if (doc && opened) { try { doc.close(SaveOptions.NO); } catch (e2) {} }
        scriptPrefs.userInteractionLevel = level;
        scriptPrefs.measurementUnit = unit;
    }
})(arguments);
