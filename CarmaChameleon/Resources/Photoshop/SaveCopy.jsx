// CarmaChameleon (.psd → PNG / PDF): Photoshop saves a copy of the document.
// Saving as a copy never changes the document's file, so a document already open stays open.
// arguments: [inputPath, outputPath, kind ("png" | "pdf")]
// Returns "OK" plus tab-separated notes ("open", "unsaved"), or "ERROR:<reason>".
(function (args) {
    var input = new File(args[0]), output = new File(args[1]), kind = args[2];
    var dialogs = app.displayDialogs, doc = null, opened = false, notes = [];
    app.displayDialogs = DialogModes.NO; // missing fonts, PDF option warnings… must not block
    try {
        // Opening a file that is already open only brings it to the front; the document count tells which it was.
        var countBefore = app.documents.length;
        doc = app.open(input);
        opened = app.documents.length > countBefore;
        if (!opened) { notes.push("open"); if (!doc.saved) notes.push("unsaved"); }
        var options, source = doc;
        if (kind === "pdf") {
            options = new PDFSaveOptions();
            options.preserveEditing = false;
            options.embedColorProfile = true;
        } else {
            options = new PNGSaveOptions();
            // PNG holds only RGB / grayscale up to 16 bits: convert a duplicate, never the user's document.
            var mode = doc.mode;
            if (mode !== DocumentMode.RGB && mode !== DocumentMode.GRAYSCALE || doc.bitsPerChannel === BitsPerChannelType.THIRTYTWO) {
                source = doc.duplicate();
                if (source.bitsPerChannel === BitsPerChannelType.THIRTYTWO) source.bitsPerChannel = BitsPerChannelType.SIXTEEN;
                if (mode !== DocumentMode.RGB && mode !== DocumentMode.GRAYSCALE) source.changeMode(ChangeMode.RGB);
            }
        }
        try { source.saveAs(output, options, true, Extension.LOWERCASE); }
        finally { if (source !== doc) source.close(SaveOptions.DONOTSAVECHANGES); }
        return ["OK"].concat(notes).join("\t");
    } catch (e) {
        return "ERROR:" + (e.message || e);
    } finally {
        if (doc && opened) { try { doc.close(SaveOptions.DONOTSAVECHANGES); } catch (e2) {} }
        app.displayDialogs = dialogs;
    }
})(arguments);
