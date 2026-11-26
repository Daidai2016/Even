#target illustrator

(function () {
    var TITLE = "选中西文字符";

    function isEditable(frame) {
        if (!frame.editable) { return false; }
        var item = frame;
        while (item && item.typename !== "Document") {
            if (item.locked || item.hidden || item.visible === false) { return false; }
            item = item.parent;
        }
        return true;
    }

    function getParagraph(doc) {
        var selection = doc.selection;
        // With the Type tool, even a blinking caret is exposed as a zero-length TextRange.
        if (!selection || selection.typename !== "TextRange") { return null; }

        var paragraphs = selection.story.textRange.paragraphs;
        for (var i = 0; i < paragraphs.length; i++) {
            var paragraph = paragraphs[i];
            if (selection.start >= paragraph.start && selection.start <= paragraph.end) {
                if (selection.end > paragraph.end) { return null; }
                return paragraph;
            }
        }
        return null;
    }

    function isOnArtboard(frame, rect) {
        // A frame that crosses the artboard edge is assigned by its center.
        var bounds = frame.geometricBounds;
        var x = (bounds[0] + bounds[2]) / 2;
        var y = (bounds[1] + bounds[3]) / 2;
        return x >= rect[0] && x <= rect[2] && y <= rect[1] && y >= rect[3];
    }

    function makeRange(story, start, end) {
        var range = story.textRange;
        range.start = start;
        range.end = end;
        return range;
    }

    function addMatch(entry, start, end) {
        var runs = entry.runs;
        var last = runs.length ? runs[runs.length - 1] : null;
        if (last && last.end === start) {
            last.end = end;
        } else {
            runs.push({start: start, end: end});
        }
    }

    function findMatches(entry, range) {
        var contents = range.contents;
        if (contents.length === range.end - range.start) {
            var pattern = /[A-Za-z0-9]+/g;
            var match;
            while ((match = pattern.exec(contents)) !== null) {
                var start = range.start + match.index;
                addMatch(entry, start, start + match[0].length);
            }
            return;
        }

        // Use Illustrator offsets if the host counts a Unicode sequence differently.
        var characters = range.characters;
        for (var i = 0; i < characters.length; i++) {
            var character = characters[i];
            if (/^[A-Za-z0-9]+$/.test(character.contents)) {
                addMatch(entry, character.start, character.end);
            }
        }
    }

    function scan(doc, scope, paragraph) {
        var result = {entries: [], count: 0};
        var previousCoordinates = app.coordinateSystem;
        try {
            if (scope === "artboard") {
                app.coordinateSystem = CoordinateSystem.DOCUMENTCOORDINATESYSTEM;
            }
            var rect = scope === "artboard" ?
                doc.artboards[doc.artboards.getActiveArtboardIndex()].artboardRect : null;
            var frames = scope === "paragraph" ? paragraph.story.textFrames : doc.textFrames;
            for (var i = 0; i < frames.length; i++) {
                var frame = frames[i];
                if (!isEditable(frame) || (rect && !isOnArtboard(frame, rect))) { continue; }
                var frameRange = frame.textRange;
                var story = frameRange.story;
                var start = frameRange.start;
                var end = frameRange.end;
                if (scope === "paragraph") {
                    start = Math.max(start, paragraph.start);
                    end = Math.min(end, paragraph.end);
                }
                if (start >= end) { continue; }
                var entry = {frame: frame, story: story, start: start, end: end, runs: []};
                findMatches(entry, makeRange(story, start, end));
                if (!entry.runs.length) { continue; }
                result.entries.push(entry);
                for (var j = 0; j < entry.runs.length; j++) {
                    result.count += entry.runs[j].end - entry.runs[j].start;
                }
            }
        } finally {
            if (scope === "artboard") { app.coordinateSystem = previousCoordinates; }
        }
        return result;
    }

    function hasExactSelection(entry) {
        var selection = entry.frame.textSelection;
        var actual = [];
        var i;
        for (i = 0; i < selection.length; i++) {
            // A threaded story can expose the same selection to more than one frame.
            var start = Math.max(selection[i].start, entry.start);
            var end = Math.min(selection[i].end, entry.end);
            if (start < end) { actual.push({start: start, end: end}); }
        }
        actual.sort(function (a, b) { return a.start - b.start; });
        var merged = {runs: []};
        for (i = 0; i < actual.length; i++) {
            addMatch(merged, actual[i].start, actual[i].end);
        }
        if (merged.runs.length !== entry.runs.length) { return false; }
        for (i = 0; i < entry.runs.length; i++) {
            if (merged.runs[i].start !== entry.runs[i].start ||
                merged.runs[i].end !== entry.runs[i].end) { return false; }
        }
        return true;
    }

    function selectMatches(doc, result) {
        try {
            // Exit Type-tool editing first. In that mode Illustrator joins added ranges into a single span.
            doc.selection = null;
            app.executeMenuCommand("deselectall");
            var add = false;
            for (var i = 0; i < result.entries.length; i++) {
                var entry = result.entries[i];
                for (var j = 0; j < entry.runs.length; j++) {
                    var run = entry.runs[j];
                    makeRange(entry.story, run.start, run.end).select(add);
                    add = true;
                }
            }
            app.redraw();
            for (var k = 0; k < result.entries.length; k++) {
                if (!hasExactSelection(result.entries[k])) {
                    doc.selection = null;
                    return false;
                }
            }
            return true;
        } catch (error) {
            doc.selection = null;
            return false;
        }
    }

    function collectFonts() {
        var families = [];
        var byName = {};
        var fonts = app.textFonts;
        for (var i = 0; i < fonts.length; i++) {
            var font = fonts[i];
            var name = font.family;
            var key = "$" + name;
            if (!byName[key]) {
                byName[key] = {name: name, fonts: []};
                families.push(byName[key]);
            }
            byName[key].fonts.push({name: font.style, font: font});
        }
        function byLabel(a, b) {
            var left = a.name.toLowerCase(), right = b.name.toLowerCase();
            return left < right ? -1 : left > right ? 1 : 0;
        }
        families.sort(byLabel);
        for (var j = 0; j < families.length; j++) { families[j].fonts.sort(byLabel); }
        return families;
    }

    function numberFrom(text, label, min, max, integer) {
        if (!/^[+-]?(\d+(\.\d*)?|\.\d+)$/.test(text.replace(/^\s+|\s+$/g, ""))) {
            throw new Error(label + "请输入数字。");
        }
        var value = Number(text);
        if (value < min || value > max || (integer && Math.floor(value) !== value)) {
            throw new Error(label + "请输入 " + min + " 至 " + max +
                (integer ? " 之间的整数。" : " 之间的数值。"));
        }
        return value;
    }

    function fillFrom(doc, text) {
        var hex = text.replace(/^\s*#?|\s*$/g, "");
        if (!/^[0-9a-f]{6}$/i.test(hex)) { throw new Error("填充色请输入六位十六进制值，例如 #0066CC。"); }
        var rgb = [parseInt(hex.slice(0, 2), 16), parseInt(hex.slice(2, 4), 16),
            parseInt(hex.slice(4, 6), 16)];
        if (doc.documentColorSpace === DocumentColorSpace.CMYK) {
            var values = app.convertSampleColor(ImageColorSpace.RGB, rgb, ImageColorSpace.CMYK,
                ColorConvertPurpose.defaultpurpose);
            var cmyk = new CMYKColor();
            cmyk.cyan = values[0];
            cmyk.magenta = values[1];
            cmyk.yellow = values[2];
            cmyk.black = values[3];
            return cmyk;
        }
        var color = new RGBColor();
        color.red = rgb[0];
        color.green = rgb[1];
        color.blue = rgb[2];
        return color;
    }

    function applyMatches(result, changes) {
        // Resolve the fixed story offsets again on each write. Font and size changes can reflow frames.
        for (var i = 0; i < result.entries.length; i++) {
            var entry = result.entries[i];
            var storyRange = entry.story.textRange;
            var characters = storyRange.characters;
            for (var j = 0; j < entry.runs.length; j++) {
                var run = entry.runs[j];
                var following = run.end < storyRange.end ? characters[run.end - storyRange.start] : null;
                var hasLineEnding = following && /^[\r\n\u0003]$/.test(following.contents);
                var original = [];
                var k;
                if (hasLineEnding) {
                    // Illustrator may extend formatting from the last character to the line separator.
                    var endingAttributes = following.characterAttributes;
                    for (k = 0; k < changes.length; k++) {
                        original.push(endingAttributes[changes[k].property]);
                    }
                }
                var attributes = makeRange(entry.story, run.start, run.end).characterAttributes;
                try {
                    for (k = 0; k < changes.length; k++) {
                        attributes[changes[k].property] = changes[k].value;
                    }
                } finally {
                    if (hasLineEnding) {
                        var separator = makeRange(entry.story, run.end, run.end + 1).characterAttributes;
                        for (var p = 0; p < k; p++) {
                            var property = changes[p].property;
                            // Illustrator's JSX setter ignores tracking = 0.
                            if (typeof original[p] !== "undefined" && !(property === "tracking" && original[p] === 0)) {
                                separator[property] = original[p];
                            }
                        }
                    }
                }
            }
        }
    }

    function main() {
        if (!app.documents.length) { alert("请先打开 Illustrator 文档。", TITLE); return; }
        var doc = app.activeDocument;
        var paragraph = getParagraph(doc);
        var win = new Window("dialog", TITLE);
        win.alignChildren = "fill";
        var scopes = win.add("group");
        var paragraphButton = scopes.add("button", undefined, "选中段落西文");
        var boardButton = scopes.add("button", undefined, "选中画板西文");
        var docButton = scopes.add("button", undefined, "选中文档西文");
        var hint = win.add("statictext", undefined, "段落取自文字光标，画板取自当前活动画板。");
        paragraphButton.enabled = paragraph !== null;
        if (!paragraph) { hint.text = "段落模式需先用文字工具将光标置于一个段落。"; }
        var edit = win.add("checkbox", undefined, "在脚本中调整字符参数");
        var panel = win.add("panel", undefined, "字符参数");
        panel.alignChildren = "left";
        var fontRow = panel.add("group");
        var useFont = fontRow.add("checkbox", undefined, "字体与字重");
        var family = fontRow.add("dropdownlist");
        var style = fontRow.add("dropdownlist");
        family.preferredSize.width = 190;
        style.preferredSize.width = 125;
        family.enabled = style.enabled = false;
        var fonts = null;
        var size = field("字号（pt）", "12");
        var fill = field("填充色（HEX）", "#000000");
        var tracking = field("字距（千分之一 em）", "0");
        var shift = field("基线偏移（pt）", "0");
        panel.enabled = false;

        var status = win.add("statictext", undefined, "点击上方按钮选中英文和数字。", {multiline: true});
        status.preferredSize = [430, 40];
        var actions = win.add("group");
        actions.alignment = "right";
        var apply = actions.add("button", undefined, "应用参数");
        actions.add("button", undefined, "关闭", {name: "cancel"});
        apply.enabled = false;
        var result = null;
        var editsToApply = null;
        var wantsSelection = false;

        function field(label, initial) {
            var row = panel.add("group");
            var enabled = row.add("checkbox", undefined, label);
            enabled.preferredSize.width = 170;
            var input = row.add("edittext", undefined, initial);
            input.characters = 12;
            input.enabled = false;
            enabled.onClick = function () { input.enabled = enabled.value; };
            return {enabled: enabled, input: input};
        }

        function showStyles() {
            style.removeAll();
            if (!family.selection) { return; }
            var available = fonts[family.selection.index].fonts;
            var preferred = 0;
            for (var i = 0; i < available.length; i++) {
                style.add("item", available[i].name);
                if (/^(regular|normal|roman)$/i.test(available[i].name)) { preferred = i; }
            }
            style.selection = preferred;
        }

        useFont.onClick = function () {
            if (useFont.value && !fonts) {
                try {
                    var available = collectFonts();
                    if (!available.length) { throw new Error("没有读取到可用字体。"); }
                    fonts = available;
                    for (var i = 0; i < fonts.length; i++) { family.add("item", fonts[i].name); }
                    family.selection = 0;
                    showStyles();
                } catch (error) {
                    useFont.value = false;
                    alert(error.message, TITLE);
                }
            }
            family.enabled = style.enabled = useFont.value;
        };
        family.onChange = showStyles;

        edit.onClick = function () {
            panel.enabled = edit.value;
            apply.enabled = edit.value && result !== null && result.count > 0;
            if (!edit.value) { status.text = "点击上方按钮选中英文和数字。"; }
            else if (result && result.count) { status.text = summary(result); }
            else { status.text = "点击上方按钮查找英文和数字，再应用勾选的参数。"; }
        };

        function summary(matches) {
            return matches.label + "找到 " + matches.count + " 个字符，涉及 " +
                matches.entries.length + " 个文本框。";
        }

        function choose(scope, label) {
            result = null;
            apply.enabled = false;
            try {
                result = scan(doc, scope, paragraph);
                result.label = label;
                if (!result.count) { status.text = "此范围没有匹配的英文或数字。"; return; }
                if (!edit.value) {
                    wantsSelection = true;
                    win.close(1);
                    return;
                }
                status.text = summary(result);
                apply.enabled = true;
            } catch (error) {
                status.text = "查找失败。";
                alert(error.message, TITLE);
            }
        }

        paragraphButton.onClick = function () { choose("paragraph", "当前段落"); };
        boardButton.onClick = function () { choose("artboard", "当前画板"); };
        docButton.onClick = function () { choose("document", "当前文档"); };

        apply.onClick = function () {
            var changes = [];
            try {
                if (useFont.value) {
                    if (!family.selection || !style.selection) { throw new Error("请选择字体和字重。"); }
                    changes.push({property: "textFont", value: fonts[family.selection.index].fonts[style.selection.index].font});
                }
                if (size.enabled.value) {
                    changes.push({property: "size", value: numberFrom(size.input.text, "字号", 0.1, 1296, false)});
                }
                if (fill.enabled.value) { changes.push({property: "fillColor", value: fillFrom(doc, fill.input.text)}); }
                if (tracking.enabled.value) {
                    var trackingValue = numberFrom(tracking.input.text, "字距", -1000, 10000, true);
                    if (trackingValue === 0) {
                        throw new Error("字距归零请直接使用 Illustrator 字符面板。");
                    }
                    changes.push({property: "tracking", value: trackingValue});
                }
                if (shift.enabled.value) {
                    changes.push({property: "baselineShift", value: numberFrom(shift.input.text, "基线偏移", -1296, 1296, false)});
                }
                if (!changes.length) { throw new Error("请勾选需要调整的字符参数。"); }
            } catch (error) {
                alert(error.message, TITLE);
                return;
            }
            editsToApply = changes;
            win.close(1);
        };

        win.center();
        do {
            wantsSelection = false;
            win.show();
            if (!wantsSelection || selectMatches(doc, result)) { break; }
            edit.value = true;
            panel.enabled = true;
            apply.enabled = true;
            status.text = summary(result) + "\nIllustrator 未能保留完整选区，可在此应用参数。";
        } while (wantsSelection);
        if (editsToApply) {
            try { applyMatches(result, editsToApply); }
            catch (error) {
                alert("应用参数时中断。若已出现格式变化，可用编辑 > 撤销恢复。\n" + error.message, TITLE);
            }
        }
    }

    try { main(); }
    catch (error) { alert("脚本无法运行。\n" + error.message, TITLE); }
}());
