#target illustrator
/* Illustrator host regression. Creates its own test document; does not touch existing documents. */
(function () {
    var here = File($.fileName).parent;
    var sourceFile = File(here.parent + "/jsx/artboard_rename_v01.jsx");
    var root = here.parent.parent.parent;
    var folder = Folder(root + "/work/artboard_rename_host_test");
    if (!folder.exists) { folder.create(); }
    var report = File(folder + "/results.txt");
    var lines = ["Illustrator " + app.version, "OS: " + $.os, "Date: " + new Date()];
    function check(value, message) {
        if (!value) { throw new Error(message); }
        lines.push("PASS " + message);
    }
    function writeReport() {
        report.encoding = "UTF-8";
        if (!report.open("w")) { throw new Error("Cannot write test report"); }
        report.write(lines.join("\n")); report.close();
    }
    var d;
    try {
        d = app.documents.add(DocumentColorSpace.RGB, 80 * 72 / 25.4, 200 * 72 / 25.4);
        d.artboards[0].name = "原名称甲";
        d.artboards.add([300, 400, 600, 200]).name = "原名称乙";
        d.artboards.add([700, 400, 800, 350]).name = "原名称丙";
        d.artboards.setActiveArtboardIndex(0);
        var artwork = d.pathItems.rectangle(100, 10, 20, 30);
        var originalBounds = artwork.geometricBounds.join(",");
        sourceFile.encoding = "UTF-8";
        if (!sourceFile.open("r")) { throw new Error("Cannot read source script"); }
        var source = sourceFile.read(); sourceFile.close();
        source = source.replace(/^#target[^\r\n]*/, "");
        var marker = "refresh(); win.center(); win.show();";
        check(source.indexOf(marker) >= 0, "Test hook matches current source");
        var hook = function () {
            function setMode(n) { for (var k = 0; k < modes.length; k++) { modes[k].value = k === n; } }
            function verifyFirst(expected, label) {
                check(refresh(), label + " preview valid");
                check(plan[0].after === expected, label + " preview = " + expected);
                applyPlan(boards, plan);
                check(boards[0].name === expected, label + " actual artboard name");
            }
            setMode(0); verifyFirst(documentName, "Document mode");
            setMode(1); scale.selection = 1;
            verifyFirst("800×2000mm", "Size 1:10 mm");
            unit.selection = 1; verifyFirst("80×200cm", "Size 1:10 cm");
            scale.selection = 2; unit.selection = 2; verifyFirst("8×20m", "Size 1:100 m");
            scale.selection = 0; unit.selection = 3; verifyFirst("227×567px", "Size 1:1 px");
            scale.selection = 3; left.text = "2"; right.text = "5"; unit.selection = 0;
            verifyFirst("200×500mm", "Custom ratio 2:5");
            setMode(2); scale.selection = 1; verifyFirst(documentName + "_800×2000mm", "Document + size");
            setMode(3); template.text = "画板 @_#_$（正面）-2026!";
            verifyFirst("画板 01_" + documentName + "_800×2000mm（正面）-2026!", "Chinese custom template");
            template.text = "\\@\\#\\$"; verifyFirst("@#$", "Escaped symbols");
            template.text = "编号@"; scope.selection = 2; range.text = "3,1,1";
            check(refresh() && plan.length === 2 && plan[0].index === 0 && plan[1].index === 2, "Specified range sorted and deduplicated");
            var untouched = boards[1].name; applyPlan(boards, plan);
            check(boards[0].name === "编号01" && boards[2].name === "编号03" && boards[1].name === untouched, "Only specified boards renamed");
            scope.selection = 1; boards.setActiveArtboardIndex(1); template.text = "当前@";
            check(refresh() && plan.length === 1 && plan[0].index === 1, "Current artboard scope");
            applyPlan(boards, plan); check(boards[1].name === "当前02", "Current artboard actual write");
            scope.selection = 2; range.text = "0"; check(!refresh() && !run.enabled, "Invalid range blocked");
            scope.selection = 0; template.text = " "; check(!refresh() && !run.enabled, "Empty name blocked");
            setMode(1); scale.selection = 3; right.text = "0"; check(!refresh() && !run.enabled, "Zero scale blocked");
            scale.selection = 0; unit.selection = 2; check(refresh() && status.text.indexOf("0") >= 0, "Rounded zero warning");
            check(artwork.geometricBounds.join(",") === originalBounds, "Artwork geometry unchanged");
            check(boards.length === 3, "Artboard count unchanged");
            for (var k = 0; k < 3; k++) { boards[k].name = ["原名称甲", "原名称乙", "原名称丙"][k]; }
            boards.setActiveArtboardIndex(0);
        };
        // Replace only the modal launch with checks using the actual UI controls and functions.
        source = source.replace(marker, "(" + hook.toString() + ")();");
        source = source.replace('try { main(); } catch (error) { alert("画板重命名无法运行：" + error.message); }', 'main();');
        eval(source);
        lines.push("COMPLETE: host API and ScriptUI control logic passed. Visual interaction remains separate.");
        writeReport();
        alert("真机逻辑验证通过。\n已创建 3 个测试画板，接下来打开原脚本进行界面验证。", "验证结果");
        $.evalFile(sourceFile);
    } catch (error) {
        lines.push("FAIL " + error.message + " line " + error.line);
        writeReport(); alert("测试失败：" + error.message + "\n行：" + error.line);
    }
}());
