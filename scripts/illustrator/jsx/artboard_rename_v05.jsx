#target illustrator

/* 画板批量重命名 v05 | Illustrator 2024+ | UTF-8 / ES3
 * 作者：Even Wu | 联系作者：huaping.woo@gmail.com
 * 单文件运行；只修改画板名称，不自动保存文档。
 */
(function () {
    function trim(s) { return String(s).replace(/^\s+|\s+$/g, ""); }
    function positive(s) {
        s = trim(s);
        if (!/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(s) || !isFinite(Number(s)) || Number(s) <= 0) {
            throw new Error("比例两侧必须是大于 0 的数字，例如 1 : 20。");
        }
        return Number(s);
    }
    function indices(text, count) {
        var parts = text.split(/[,，]/), result = [], seen = {}, i, m, a, b, j;
        for (i = 0; i < parts.length; i++) {
            m = /^\s*(\d+)\s*(?:-\s*(\d+)\s*)?$/.exec(parts[i]);
            if (!m) { throw new Error("画板编号格式：1,3,5-8（编号以画板面板顺序为准）。"); }
            a = Number(m[1]); b = m[2] ? Number(m[2]) : a;
            if (a < 1 || b > count || a > b) { throw new Error("画板编号超出范围或区间顺序错误。"); }
            for (j = a; j <= b; j++) { if (!seen[j]) { seen[j] = true; result.push(j - 1); } }
        }
        result.sort(function (a, b) { return a - b; });
        return result;
    }
    function dimensions(rect, factor, unit) {
        var conversion = { mm: 25.4 / 72, cm: 2.54 / 72, m: 0.0254 / 72, px: 1 };
        var w = Math.abs(rect[2] - rect[0]) * factor * conversion[unit];
        var h = Math.abs(rect[1] - rect[3]) * factor * conversion[unit];
        if (!isFinite(w) || !isFinite(h) || w <= 0 || h <= 0 || w > 9007199254740991 || h > 9007199254740991) {
            throw new Error("画板尺寸或比例无效，或换算结果过大。");
        }
        // 抑制单位换算造成的浮点尾差，仅在最后一步取整。
        w = Math.round(w + Math.min(0.0000001, w * 1e-12));
        h = Math.round(h + Math.min(0.0000001, h * 1e-12));
        return { text: w + "×" + h + unit, zero: w === 0 || h === 0 };
    }
    function makeName(mode, documentName, size, index, count) {
        if (mode === 0 || mode === 1 || mode === 3 || mode === 5) {
            if (!trim(documentName) || /[\x00-\x1f\x7f]/.test(documentName)) {
                throw new Error("命名用文档名不能为空或包含换行、制表等控制字符。");
            }
            documentName = trim(documentName);
        }
        // 按整个文档的画板数量统一位数；指定范围仍使用原画板编号。
        var serial = String(index), width = count > 99 ? 3 : 2;
        while (serial.length < width) { serial = "0" + serial; }
        if (mode === 0) { return serial + "_" + documentName + "_" + size; }
        if (mode === 1) { return serial + "_" + documentName; }
        if (mode === 2) { return serial + "_" + size; }
        if (mode === 3) { return documentName + "_" + size; }
        if (mode === 4) { return serial; }
        if (mode === 5) { return documentName; }
        if (mode === 6) { return size; }
        throw new Error("请选择有效的命名模式。");
    }
    function letterNumber(number) {
        var result = "";
        while (number > 0) {
            number--;
            result = String.fromCharCode(65 + number % 26) + result;
            number = Math.floor(number / 26);
        }
        return result;
    }
    function uniqueNames(boards, plan) {
        var targets = {}, counts = {}, reserved = {}, used = {}, next = {}, i, key, base, candidate, number, numbered = 0;
        for (i = 0; i < plan.length; i++) {
            targets[plan[i].index] = true;
            key = "n:" + plan[i].after;
            counts[key] = (counts[key] || 0) + 1;
            reserved[key] = true;
        }
        // 非目标画板保持原名。若它们自身重名，必须扩大处理范围才能保证全局唯一。
        for (i = 0; i < boards.length; i++) {
            if (!targets[i]) {
                key = "n:" + String(boards[i].name);
                if (used[key]) { throw new Error("未处理画板中存在同名：" + boards[i].name + "。请选择全部画板，或将这些同名画板纳入指定范围。"); }
                used[key] = true;
            }
        }
        // 先保留所有原始候选名，避免编号占用后续画板原本唯一的名称。
        for (i = 0; i < plan.length; i++) {
            base = plan[i].after; key = "n:" + base; candidate = base;
            if (counts[key] > 1 || used[key]) {
                number = next[key] || 1;
                do {
                    candidate = base + "-" + letterNumber(number);
                    number++;
                } while (used["n:" + candidate] || reserved["n:" + candidate]);
                next[key] = number;
                numbered++;
            }
            plan[i].after = candidate;
            used["n:" + candidate] = true;
        }
        return numbered;
    }
    function applyPlan(boards, plan) {
        var i, changed = [], failed = [], entry;
        try {
            for (i = 0; i < plan.length; i++) {
                entry = plan[i];
                if (entry.before !== entry.after) {
                    changed.push(entry);
                    boards[entry.index].name = entry.after;
                    if (boards[entry.index].name !== entry.after) { throw new Error("画板名称未完整写入。"); }
                }
            }
        } catch (error) {
            for (i = changed.length - 1; i >= 0; i--) {
                try {
                    boards[changed[i].index].name = changed[i].before;
                    if (boards[changed[i].index].name !== changed[i].before) { throw new Error("恢复失败"); }
                } catch (restoreError) { failed.push(changed[i].index + 1); }
            }
            throw new Error("重命名失败：" + error.message + (failed.length ? "\n以下画板未能恢复，请检查：" + failed.join(", ") : "\n已恢复本次涉及的原名称。"));
        }
        return changed.length;
    }

    function main() {
        if (parseInt(app.version, 10) < 28) { alert("请使用 Adobe Illustrator 2024 或更新版本。"); return; }
        if (!app.documents.length) { alert("请先打开一个 Illustrator 文档。"); return; }
        var doc = app.activeDocument, boards = doc.artboards;
        var documentName = String(doc.name).replace(/\.(ai|ait|pdf|eps|svg|svgz)$/i, "");
        var canvasFactor = Number(doc.scaleFactor) || 1;
        var win = new Window("dialog", "画板批量重命名 v05");
        win.orientation = "column"; win.alignChildren = "fill"; win.spacing = 12; win.margins = 18;
        win.add("statictext", undefined, "文档：" + documentName + "  ｜  共 " + boards.length + " 个画板");
        var modePanel = win.add("panel", undefined, "命名模式");
        modePanel.alignChildren = "left"; modePanel.margins = 14;
        var modeSelect = modePanel.add("dropdownlist", undefined, ["序号+文档+尺寸名", "序号+文档名", "序号+尺寸名", "文档名+尺寸名", "仅序号", "仅文档名", "仅尺寸名"]);
        modeSelect.selection = 0; modeSelect.preferredSize.width = 360;
        var nameRow = modePanel.add("group");
        nameRow.add("statictext", undefined, "命名用文档名：");
        var namingName = nameRow.add("edittext", undefined, documentName); namingName.preferredSize.width = 450;
        modePanel.add("statictext", undefined, "可简化为项目或内容名称，仅用于画板命名，不修改实际文件名。");
        modePanel.add("statictext", undefined, "序号按画板面板顺序：99 个以内为 01 起；超过 99 个统一为 001 起。");
        var targetPanel = win.add("panel", undefined, "应用范围"); targetPanel.alignChildren = "left"; targetPanel.margins = 14;
        var targetRow = targetPanel.add("group");
        var scope = targetRow.add("dropdownlist", undefined, ["全部画板", "当前画板", "指定编号"]); scope.selection = 0;
        var range = targetRow.add("edittext", undefined, "1"); range.characters = 28;
        targetPanel.add("statictext", undefined, "指定编号示例：1,3,5-8；混合比例的画板请按范围分别执行。");
        var sizePanel = win.add("panel", undefined, "尺寸命名设置"); sizePanel.alignChildren = "left"; sizePanel.margins = 14;
        var scaleRow = sizePanel.add("group"); scaleRow.add("statictext", undefined, "比例尺：");
        var scale = scaleRow.add("dropdownlist", undefined, ["1:1（原尺寸）", "1:10", "1:100", "比例自定义"]); scale.selection = 0;
        var left = scaleRow.add("edittext", undefined, "1"); left.characters = 6;
        scaleRow.add("statictext", undefined, ":");
        var right = scaleRow.add("edittext", undefined, "20"); right.characters = 6;
        var unitRow = sizePanel.add("group"); unitRow.add("statictext", undefined, "精确单位：");
        var unit = unitRow.add("dropdownlist", undefined, ["mm", "cm", "m", "px"]); unit.selection = 0;
        unitRow.add("statictext", undefined, "宽×高，四舍五入到整数");
        sizePanel.add("statictext", undefined, "比例 = 图上 : 实际；1:10 表示尺寸乘 10。px 按 Illustrator 的 1pt = 1px。");
        if (canvasFactor !== 1) { sizePanel.add("statictext", undefined, "已识别大画布：自动还原画板尺寸后，再应用所选制作比例。"); }
        var previewPanel = win.add("panel", undefined, "命名预览（执行前请核对）"); previewPanel.alignChildren = "fill"; previewPanel.margins = 12;
        var list = previewPanel.add("listbox", undefined, [], { numberOfColumns: 3, showHeaders: true, columnTitles: ["编号", "原名称", "新名称"], columnWidths: [50, 245, 305] });
        list.preferredSize = [620, 190];
        var status = win.add("statictext", undefined, "", { multiline: true }); status.preferredSize = [620, 42];
        var buttons = win.add("group"); buttons.alignment = "right";
        var help = buttons.add("button", undefined, "使用说明");
        var run = buttons.add("button", undefined, "确认重命名", { name: "ok" });
        buttons.add("button", undefined, "取消", { name: "cancel" });
        var plan = [];
        function refresh() {
            var mode = modeSelect.selection.index, usesSize, factor = 1, targets = [], j, size, name, item, zero = false, numbered = 0;
            usesSize = mode === 0 || mode === 2 || mode === 3 || mode === 6;
            namingName.enabled = mode === 0 || mode === 1 || mode === 3 || mode === 5;
            sizePanel.enabled = usesSize;
            left.enabled = right.enabled = usesSize && scale.selection.index === 3;
            range.enabled = scope.selection.index === 2;
            list.removeAll(); plan = []; run.enabled = false;
            try {
                if (usesSize) {
                    if (scale.selection.index === 1) { factor = 10; }
                    if (scale.selection.index === 2) { factor = 100; }
                    if (scale.selection.index === 3) { factor = positive(right.text) / positive(left.text); }
                }
                if (scope.selection.index === 0) { for (j = 0; j < boards.length; j++) { targets.push(j); } }
                else if (scope.selection.index === 1) { targets.push(boards.getActiveArtboardIndex()); }
                else { targets = indices(range.text, boards.length); }
                for (j = 0; j < targets.length; j++) {
                    size = usesSize ? dimensions(boards[targets[j]].artboardRect, factor * canvasFactor, unit.selection.text) : { text: "", zero: false };
                    zero = zero || size.zero;
                    name = makeName(mode, namingName.text, size.text, targets[j] + 1, boards.length);
                    if (!trim(name) || /[\x00-\x1f\x7f]/.test(name)) { throw new Error("名称不能为空或包含换行、制表等控制字符。"); }
                    plan.push({ index: targets[j], before: String(boards[targets[j]].name), after: name });
                }
                numbered = uniqueNames(boards, plan);
                for (j = 0; j < plan.length; j++) {
                    item = list.add("item", String(plan[j].index + 1)); item.subItems[0].text = plan[j].before; item.subItems[1].text = plan[j].after;
                }
                status.text = "将处理 " + plan.length + " 个画板；已自动编号 " + numbered + " 个，全篇画板名称无重复。" + (zero ? "\n注意：部分尺寸取整后为 0，建议改用更小的单位。" : "");
                run.enabled = plan.length > 0;
                return true;
            } catch (error) { plan = []; status.text = error.message; return false; }
        }
        modeSelect.onChange = scope.onChange = scale.onChange = unit.onChange = refresh;
        namingName.onChanging = range.onChanging = left.onChanging = right.onChanging = refresh;
        help.onClick = function () {
            alert("七种下拉模式：序号+文档+尺寸名、序号+文档名、序号+尺寸名、文档名+尺寸名、仅序号、仅文档名、仅尺寸名。\n默认：序号+文档+尺寸名，例如 01_展架_800×2000mm。\n\n“命名用文档名”默认读取原文档名（不含扩展名），可输入中文、数字和常规符号，修改后实时更新预览；首尾空白自动去除，不修改实际文件名。不含文档名的模式下该输入框禁用。各组成部分以 _ 连接，尺寸固定使用乘号 ×。序号采用画板面板顺序：文档共 99 个以内为 01、02…；超过 99 个统一为 001、002…100。仅处理部分画板时仍按整个文档数量确定位数，不从 1 重新编号；1000 及以上保留完整数字。\n\n同名自动添加 -A、-B…-Z、-AA、-AB 等编号，已占用编号会跳过；预览显示最终名称。若未处理画板彼此重名，请扩大处理范围。\n\n比例为图上:实际，支持正数及小数。所有目标画板使用同一比例；混合比例请分批处理。单位可选 mm、cm、m、px，换算后四舍五入到整数。\n\n只修改画板名称，不调整画板、图稿或保存文件。取消不会修改文档。\n\n作者：Even Wu\n联系作者：huaping.woo@gmail.com", "使用说明 v05");
        };
        run.onClick = function () {
            if (!refresh()) { return; }
            var started = new Date().getTime(), count;
            try { count = applyPlan(boards, plan); }
            catch (error) { alert(error.message, "重命名失败"); refresh(); return; }
            win.close(1);
            alert("完成：已重命名 " + count + " 个画板；名称未变化 " + (plan.length - count) + " 个。\n耗时：" + ((new Date().getTime() - started) / 1000).toFixed(2) + " 秒。\n文档尚未自动保存，请核对后保存。", "画板重命名");
        };
        refresh(); win.center(); win.show();
    }
    try { main(); } catch (error) { alert("画板重命名无法运行：" + error.message); }
}());
