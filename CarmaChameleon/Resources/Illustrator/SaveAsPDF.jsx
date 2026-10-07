// CarmaChameleon (official .ai → PDF): export the document from Illustrator with an Adobe PDF preset.
// Based on sttk3's exportPDF (exportForScreens + ExportForScreensPDFOptions.pdfPreset, © 2021 sttk3.com):
// unlike saveAs, exporting never changes the document's file or save target, so a document the user
// already has open is exported as it is and stays open.
// arguments: [inputPath, outputFolder, presetName ("" = Illustrator default)]
// Returns "OK" plus tab-separated notes ("open", "unsaved", "links"), or "ERROR:<reason>".
(function (args) {
    var input = new File(args[0]), folder = new Folder(args[1]), preset = args.length > 2 ? args[2] : "";
    if (Number(app.version.split(".")[0]) < 22) return "ERROR:tooOld"; // exportForScreens needs CC 2018+

    var presets = app.PDFPresetsList, found = !preset;
    for (var p = 0; p < presets.length && !found; p++) found = presets[p] == preset;
    if (!found) return "ERROR:presetMissing";

    var doc = null, opened = false;
    for (var i = 0; i < app.documents.length; i++) {
        try { if (app.documents[i].fullName.fsName == input.fsName) { doc = app.documents[i]; break; } } catch (e) {}
    }
    var notes = [];
    if (doc) { notes.push("open"); if (!doc.saved) notes.push("unsaved"); }

    var prefs = app.preferences, folderKey = "plugin/SmartExportUI/CreateFoldersPreference";
    var level = app.userInteractionLevel, createFolders = prefs.getBooleanPreference(folderKey);
    app.userInteractionLevel = UserInteractionLevel.DONTDISPLAYALERTS; // missing fonts / links must not block
    try {
        if (!doc) { doc = app.open(input); opened = true; }
        for (var k = 0; k < doc.placedItems.length; k++) {
            try { doc.placedItems[k].file; } catch (e) { notes.push("links"); break; }
        }
        var options = new ExportForScreensPDFOptions();
        if (preset) options.pdfPreset = preset;
        var target = new ExportForScreensItemToExport();
        target.document = true;
        target.artboards = "";
        prefs.setBooleanPreference(folderKey, false); // no "PDF" subfolder
        doc.exportForScreens(folder, ExportForScreensType.SE_PDF, options, target);
        return ["OK"].concat(notes).join("\t");
    } catch (e) {
        return "ERROR:" + e.message;
    } finally {
        prefs.setBooleanPreference(folderKey, createFolders);
        if (doc && opened) { try { doc.close(SaveOptions.DONOTSAVECHANGES); } catch (e2) {} }
        app.userInteractionLevel = level;
    }
})(arguments);
