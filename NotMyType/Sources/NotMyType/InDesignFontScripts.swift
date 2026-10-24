import Foundation

/// InDesign の中の操作（indesign-scripts の IdFontConverter.jsx v1.1.6 の対象の集め方・ロック・適用・フォントの索引をほぼそのまま写したもの）。
/// 名前の変換は Illustrator 版と同じ FontConverterRules（ファミリーの表・特殊シリーズ・AXIS・学参・ウェイト順が同じことを 2026-10-24 に確認）。
/// 送り方は do script … language javascript。JSX は1行目に「OK」か「ERR」を返す
enum InDesignFontScripts {
    private static func options(_ settings: ConverterSettings) -> String {
        IllustratorBridge.literal([
            "target": settings.target.rawValue, "locked": settings.includeLocked, "hidden": settings.includeHidden,
            "styles": settings.includeStyles, "composite": settings.includeComposite,
        ] as [String: Any])
    }

    /// 対象のテキスト・スタイル・合成フォントで使われているフォントの PostScript 名
    static func scan(_ settings: ConverterSettings) -> String {
        prelude(settings) + #"""
            var problem = prepareTargets();
            if (problem) return "ERR\n" + problem;
            if (targets.length === 0 && !OPT.styles && !OPT.composite) return "ERR\nnoTarget";
            var seen = {}, names = [];
            function note(name) { if (name && !seen["_" + name]) { seen["_" + name] = true; names.push(name); } }
            for (var t = 0; t < targets.length; t++) {
                var fonts = appliedFontsOf(targets[t].ranges);
                for (var f = 0; f < fonts.length; f++) note(fontPsNameOf(fonts[f]));
            }
            if (OPT.styles) {
                var styleLists = [activeDocument.allParagraphStyles, activeDocument.allCharacterStyles];
                for (var s = 0; s < styleLists.length; s++) {
                    for (var k = 0; k < styleLists[s].length; k++) note(styleFontPsName(styleLists[s][k]));
                }
            }
            if (OPT.composite) {
                var compositeFonts = activeDocument.compositeFonts;
                for (var c = 0; c < compositeFonts.length; c++) {
                    var entries = compositeFonts[c].compositeFontEntries;
                    for (var e = 0; e < entries.length; e++) note(styleFontPsName(entries[e]));
                }
            }
            return "OK\n" + names.join("\n");
        })();
        """#
    }

    /// InDesign で使える（status が INSTALLED の）フォントだけを返す
    static func installed(_ names: [String]) -> String {
        #"""
        (function () {
            var NAMES = \#(IllustratorBridge.literal(names));
            var installedFontByPs = {};
            var allFontByPs = {};
        \#(indexFunction)
            indexFonts();
            var found = [];
            for (var i = 0; i < NAMES.length; i++) if (installedFontByPs.hasOwnProperty(NAMES[i])) found.push(NAMES[i]);
            return "OK\n" + found.join("\n");
        })();
        """#
    }

    /// 旧名 → 新名で置き換え（全体を1回の取り消しにまとめる）、変えたストーリーの数を返す
    static func apply(_ settings: ConverterSettings, map: [String: String]) -> String {
        prelude(settings) + #"""
            var problem = prepareTargets();
            if (problem) return "ERR\n" + problem;
            var installedFontByPs = {};
            var allFontByPs = {};
        \#(indexFunction)
            indexFonts();
            function getFontObject(name) { return installedFontByPs[name]; }
            var OLD = \#(IllustratorBridge.literal(Array(map.keys)));
            var NEW = \#(IllustratorBridge.literal(Array(map.values)));
            var nameMap = {};
            for (var m = 0; m < OLD.length; m++) nameMap[OLD[m]] = NEW[m];
            var includeStyles = OPT.styles, includeComposite = OPT.composite;
        \#(applyFunctions)
            var changedCount = 0;
            app.doScript(function () {
                var countedStoryIds = {};
                for (var tj = 0; tj < targets.length; tj++) {
                    var target = targets[tj];
                    if (applyChangesToTarget(target, nameMap) > 0) {
                        var storyId = null;
                        try { storyId = target.story.id; } catch (e) { storyId = null; }
                        if (storyId === null) {
                            changedCount++;
                        } else if (!countedStoryIds[storyId]) {
                            countedStoryIds[storyId] = true;
                            changedCount++;
                        }
                    }
                }
                if (includeStyles) {
                    applyChangesToStyles(activeDocument.allParagraphStyles, nameMap);
                    applyChangesToStyles(activeDocument.allCharacterStyles, nameMap);
                }
                if (includeComposite) applyChangesToCompositeFonts(nameMap);
            }, ScriptLanguage.JAVASCRIPT, undefined, UndoModes.ENTIRE_SCRIPT, "フォントを統一");
            return "OK\n" + changedCount;
        })();
        """#
    }

    /// 共通：ドキュメントの確認と対象の集め方。prepareTargets() は問題があればその理由（noSelection・noLayoutWindow）を返す
    private static func prelude(_ settings: ConverterSettings) -> String {
        #"""
        (function () {
            var OPT = \#(options(settings));
            if (app.documents.length === 0) return "ERR\nnoDocument";
            var activeDocument = app.activeDocument;
            var includeLocked = OPT.locked, includeHidden = OPT.hidden;
            var TEXT_TYPES = {
                Text: 1, Story: 1, Paragraph: 1, Line: 1, Word: 1, Character: 1,
                TextStyleRange: 1, InsertionPoint: 1, TextColumn: 1, Cell: 1
            };
            var seenStoryIds = {};
            var targets = [];
        \#(commonFunctions)
            function prepareTargets() {
                if ((OPT.target === "selection" || OPT.target === "story") && app.selection.length === 0) return "noSelection";
                if (OPT.target === "spread") {
                    var isLayoutWindow = false;
                    try { isLayoutWindow = (app.activeWindow.constructor.name === "LayoutWindow"); } catch (e) { isLayoutWindow = false; }
                    if (!isLayoutWindow) return "noLayoutWindow";
                }
                collectTargets(OPT.target);
                return null;
            }

        """#
    }

    private static let commonFunctions = #"""
    function collectTargets(mode) {
        if (mode === "document") {
            var stories = activeDocument.stories;
            for (var i = 0; i < stories.length; i++) {
                addStoryInScope(stories[i]);
            }
            return;
        }
        if (mode === "story") {
            collectStoriesFromSelection(app.selection);
            return;
        }
        if (mode === "spread") {
            var spreadFrames = collectActiveSpreadTextFrames();
            for (var s = 0; s < spreadFrames.length; s++) {
                if (frameInScope(spreadFrames[s])) addFrameTarget(spreadFrames[s]);
            }
            return;
        }
        collectFromSelection(app.selection);
    }

    function collectActiveSpreadTextFrames() {
        var result = [];
        try {
            var spread = app.activeWindow.activeSpread;
            var items = spread.allPageItems;
            for (var i = 0; i < items.length; i++) {
                if (items[i].constructor.name === "TextFrame") result.push(items[i]);
            }
        } catch (e) { }
        return result;
    }

    function collectFromSelection(items) {
        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            var typeName;
            try { typeName = item.constructor.name; } catch (e) { continue; }

            if (typeName === "TextFrame") {
                if (frameInScope(item)) addStoryTarget(item.parentStory);
            } else if (typeName === "Cell") {
                var cellText = cellTextOf(item);
                if (cellText) addTextTarget(cellText);
            } else if (TEXT_TYPES[typeName]) {
                addTextTarget(item); // 選択した文字だけを変える / only the selected characters
            } else if (typeName === "Group") {
                collectFromSelection(item.pageItems);
            }
        }
    }

    function collectStoriesFromSelection(items) {
        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            var typeName;
            try { typeName = item.constructor.name; } catch (e) { continue; }

            if (typeName === "TextFrame") {
                if (frameInScope(item)) addStoryTarget(item.parentStory);
            } else if (typeName === "Cell") {
                var cellText = cellTextOf(item);
                if (cellText) {
                    try { addStoryTarget(cellText.parentStory); } catch (e2) { }
                }
            } else if (TEXT_TYPES[typeName]) {
                try { addStoryTarget(item.parentStory); } catch (e3) { }
            } else if (typeName === "Group") {
                collectStoriesFromSelection(item.pageItems);
            }
        }
    }

    function cellTextOf(cell) {
        try {
            var texts = cell.texts;
            if (texts.length > 0) return texts[0];
        } catch (e) { }
        return null;
    }

    function addStoryTarget(story) {
        if (!story || !story.isValid) return;
        var storyId;
        try { storyId = story.id; } catch (e) { return; }
        if (seenStoryIds[storyId]) return;
        seenStoryIds[storyId] = true;

        var frames = collectionToArray(story.textContainers);
        pushTarget(story, story.textStyleRanges, frames, null);
        addNestedTextTargets(story, story, frames);
    }

    function addStoryInScope(story) {
        var frames = collectionToArray(story.textContainers);
        var framesInScope = [];
        for (var i = 0; i < frames.length; i++) {
            if (frameInScope(frames[i])) framesInScope.push(frames[i]);
        }
        if (framesInScope.length === 0) return;
        if (framesInScope.length === frames.length) {
            addStoryTarget(story);
            return;
        }
        for (var j = 0; j < framesInScope.length; j++) {
            addFrameTarget(framesInScope[j]);
        }
    }

    function addFrameTarget(frame) {
        var frameText, story;
        try {
            frameText = frame.texts[0];
            if (!frameText.isValid) return;
            story = frame.parentStory;
        } catch (e) { return; }
        pushTarget(story, frameText.textStyleRanges, [frame], null);
        addNestedTextTargets(frameText, story, [frame]);
    }

    function addTextTarget(textObject) {
        var story, clip;
        try {
            story = textObject.parentStory;
            if (!story || !story.isValid) return;
            /* 挿入点だけの選択は文字が無いので対象にしない / An insertion point alone has no characters to change */
            var chars = textObject.characters;
            if (chars.length === 0) return;
            clip = {
                first: chars.firstItem().getElements()[0],
                last: chars.lastItem().getElements()[0]
            };
        } catch (e) { return; }

        var frames;
        try { frames = collectionToArray(textObject.parentTextFrames); } catch (e2) { frames = []; }
        pushTarget(story, textObject.textStyleRanges, frames, clip);
        addNestedTextTargets(textObject, story, frames);
    }

    function addNestedTextTargets(container, story, frames) {
        var tables = [], footnotes = [];
        try { tables = collectionToArray(container.tables); } catch (e) { }
        try { footnotes = collectionToArray(container.footnotes); } catch (e2) { }

        for (var t = 0; t < tables.length; t++) {
            var cells = [];
            try { cells = collectionToArray(tables[t].cells); } catch (e3) { }
            for (var c = 0; c < cells.length; c++) {
                var cellText = cellTextOf(cells[c]);
                if (!cellText) continue;
                pushTarget(story, cellText.textStyleRanges, frames, null);
                addNestedTextTargets(cellText, story, frames);
            }
        }
        for (var f = 0; f < footnotes.length; f++) {
            var footnoteText;
            try { footnoteText = footnotes[f].texts[0]; } catch (e4) { continue; }
            pushTarget(story, footnoteText.textStyleRanges, frames, null);
        }
    }

    function pushTarget(story, ranges, frames, clip) {
        targets.push({
            story: story,
            ranges: ranges,
            frames: frames,
            sortKey: sortKeyOfFrames(frames),
            clip: clip
        });
    }

    function frameInScope(frame) {
        if (!includeLocked && isFrameLocked(frame)) return false;
        if (!includeHidden && isFrameHidden(frame)) return false;
        return true;
    }

    function collectionToArray(collection) {
        var arr = [];
        try {
            for (var i = 0; i < collection.length; i++) arr.push(collection[i]);
        } catch (e) { }
        return arr;
    }

    function sortKeyOfFrames(frames) {
        try {
            if (frames.length > 0) {
                var bounds = frames[0].geometricBounds; // [y1, x1, y2, x2] = [top, left, bottom, right]
                return [bounds[0], bounds[1]];
            }
        } catch (e) { }
        return [1e9, 1e9];
    }

    function isFrameLocked(frame) {
        try { if (frame.locked) return true; } catch (e) { }
        try { if (frame.itemLayer.locked) return true; } catch (e2) { }
        var parent;
        try { parent = frame.parent; } catch (e3) { parent = null; }
        while (parent) {
            var typeName;
            try { typeName = parent.constructor.name; } catch (e4) { break; }
            if (typeName !== "Group") break;
            try { if (parent.locked) return true; } catch (e5) { }
            try { parent = parent.parent; } catch (e6) { break; }
        }
        return false;
    }

    function isFrameHidden(frame) {
        try { if (!frame.visible) return true; } catch (e) { }
        try { if (!frame.itemLayer.visible) return true; } catch (e2) { }
        var parent;
        try { parent = frame.parent; } catch (e3) { parent = null; }
        while (parent) {
            var typeName;
            try { typeName = parent.constructor.name; } catch (e4) { break; }
            if (typeName !== "Group") break;
            try { if (!parent.visible) return true; } catch (e5) { }
            try { parent = parent.parent; } catch (e6) { break; }
        }
        return false;
    }

    function appliedFontsOf(ranges) {
        var count = 0;
        try { count = ranges.length; } catch (e) { return []; }
        if (count === 0) return [];
        try {
            var bulkFonts = ranges.everyItem().appliedFont;
            if (!(bulkFonts instanceof Array)) bulkFonts = [bulkFonts];
            if (bulkFonts.length === count) return bulkFonts;
        } catch (eBulk) { }

        var fonts = [];
        for (var i = 0; i < count; i++) {
            try { fonts.push(ranges[i].appliedFont); } catch (e2) { fonts.push(null); }
        }
        return fonts;
    }

    function styleFontPsName(style) {
        try {
            return fontPsNameOf(style.appliedFont);
        } catch (e) {
            return null;
        }
    }

    function fontPsNameOf(font) {
        if (!font) return null;
        try {
            if (typeof font === "string") {
                if (!font || font.indexOf("$ID") === 0) return null;
                var resolved = app.fonts.itemByName(font);
                if (!resolved.isValid) return null;
                return resolved.postscriptName;
            }
            return font.postscriptName;
        } catch (e) {
            return null;
        }
    }
"""#

    private static let applyFunctions = #"""
    function applyChangesToTarget(target, nameMap) {
        var ranges = target.ranges;
        var fonts = appliedFontsOf(ranges);
        var clip = target.clip;
        var clipStart, clipEnd;
        if (clip) {
            try {
                clipStart = clip.first.index;
                clipEnd = clip.last.index;
            } catch (eClip) { return 0; }
        }

        var jobs = [];
        for (var i = 0; i < fonts.length; i++) {
            var psName = fontPsNameOf(fonts[i]);
            if (!psName) continue;
            var newName = nameMap[psName];
            if (!newName) continue;

            var firstChar, lastChar;
            try {
                var chars = ranges[i].characters;
                if (chars.length === 0) continue;
                firstChar = chars.firstItem().getElements()[0];
                lastChar = chars.lastItem().getElements()[0];
                if (clip) {
                    if (firstChar.index < clipStart) firstChar = clip.first;
                    if (lastChar.index > clipEnd) lastChar = clip.last;
                    if (firstChar.index > lastChar.index) continue;
                }
            } catch (e) { continue; }

            jobs.push({ first: firstChar, last: lastChar, font: getFontObject(newName) });
        }
        if (jobs.length === 0) return 0;

        var savedLocked = unlockFramesFor(target);

        var changed = false;
        try {
            for (var j = 0; j < jobs.length; j++) {
                try {
                    jobs[j].first.parent.characters.itemByRange(jobs[j].first, jobs[j].last).appliedFont = jobs[j].font;
                    changed = true;
                } catch (e3) { }
            }
        } finally {
            restoreLocks(savedLocked);
        }

        return changed ? 1 : 0;
    }

    function unlockFramesFor(target) {
        var saved = [];
        if (!includeLocked) return saved;
        for (var i = 0; i < target.frames.length; i++) {
            var frame = target.frames[i];
            pushUnlock(frame, saved);
            try { pushUnlock(frame.itemLayer, saved); } catch (e) { }
            var parent;
            try { parent = frame.parent; } catch (e2) { parent = null; }
            while (parent) {
                var typeName;
                try { typeName = parent.constructor.name; } catch (e3) { break; }
                if (typeName !== "Group") break;
                pushUnlock(parent, saved);
                try { parent = parent.parent; } catch (e4) { break; }
            }
        }
        return saved;
    }

    function pushUnlock(container, saved) {
        try {
            if (container.locked) {
                container.locked = false;
                saved.push(container);
            }
        } catch (e) { }
    }

    function restoreLocks(saved) {
        for (var i = 0; i < saved.length; i++) {
            try { saved[i].locked = true; } catch (e) { }
        }
    }

    function applyChangesToStyles(styles, nameMap) {
        for (var k = 0; k < styles.length; k++) {
            var psName = styleFontPsName(styles[k]);
            if (!psName) continue;
            var newName = nameMap[psName];
            if (!newName) continue;
            try {
                styles[k].appliedFont = getFontObject(newName);
            } catch (e) { }
        }
    }

    function applyChangesToCompositeFonts(nameMap) {
        var compositeFonts = activeDocument.compositeFonts;
        for (var c = 0; c < compositeFonts.length; c++) {
            var entries = compositeFonts[c].compositeFontEntries;
            for (var e = 0; e < entries.length; e++) {
                var psName = styleFontPsName(entries[e]);
                if (!psName) continue;
                var newName = nameMap[psName];
                if (!newName) continue;
                try {
                    entries[e].appliedFont = getFontObject(newName);
                } catch (eApply) { }
            }
        }
    }
"""#

    private static let indexFunction = #"""
    function indexFonts() {
        var fonts = app.fonts;

        var elements = null, psNames = null, statuses = null;
        try {
            elements = fonts.everyItem().getElements();
            psNames = fonts.everyItem().postscriptName;
            statuses = fonts.everyItem().status;
        } catch (bulkError) {
            elements = null;
        }

        if (elements && psNames && elements.length === psNames.length) {
            for (var i = 0; i < elements.length; i++) {
                var psName = psNames[i];
                if (!psName) continue;
                if (!allFontByPs.hasOwnProperty(psName)) allFontByPs[psName] = elements[i];
                var installed = statuses ? (statuses[i] === FontStatus.INSTALLED) : true;
                if (installed && !installedFontByPs.hasOwnProperty(psName)) installedFontByPs[psName] = elements[i];
            }
            return;
        }

        for (var j = 0; j < fonts.length; j++) {
            var font = fonts[j];
            var ps;
            try { ps = font.postscriptName; } catch (e) { continue; }
            if (!ps) continue;
            if (!allFontByPs.hasOwnProperty(ps)) allFontByPs[ps] = font;
            var inst;
            try { inst = (font.status === FontStatus.INSTALLED); } catch (e2) { inst = true; }
            if (inst && !installedFontByPs.hasOwnProperty(ps)) installedFontByPs[ps] = font;
        }
    }
"""#
}
