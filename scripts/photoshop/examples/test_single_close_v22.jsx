// Native Photoshop test: only creates/closes its own test documents.
(function () {
    var examples = new File($.fileName).parent;
    var file = new File(examples.parent.absoluteURI + '/jsx/large_format_single_file_process_v22.jsx');
    file.encoding = 'UTF-8';
    if (!file.open('r')) { throw new Error('Cannot read V22'); }
    var code = file.read(); file.close();
    code = code.replace(/^#target photoshop/, '').replace('app.bringToFront();', '')
        .replace('preview.show();', 'run = !cancelTest;').replace(/alert\(/g, 'testAlert(')
        .replace(/confirm\(/g, 'testConfirm(').replace(/exit\(\);/g, 'throw testStop;');
    var testStop = {};
    var messages = [];
    function testAlert(message) { messages.push(message); }
    function testConfirm(message) { return true; } // Only this test harness uses its own generated paths.
    function check(value, message) { if (!value) { throw new Error(message); } }
    function existsDocument(id) {
        for (var index = 0; index < app.documents.length; index++) {
            if (app.documents[index].id === id) { return true; }
        }
        return false;
    }
    function child(folder, name, directory) {
        var uri = folder.absoluteURI + '/' + encodeURIComponent(name);
        return directory ? new Folder(uri) : new File(uri);
    }
    function binaryContents(input) {
        input.encoding = 'BINARY';
        check(input.open('r'), 'Cannot read source bytes');
        var bytes = input.read(); input.close(); return bytes;
    }
    var root = child(new Folder(examples.parent.parent.parent.absoluteURI + '/work'), 'single_close_v22_' + new Date().getTime(), true);
    check(root.create(), 'Test directory');
    var previousDialogs = app.displayDialogs;
    var previousDocument = app.documents.length ? app.activeDocument : null;
    var sentinel = null;
    var testDoc = null;
    var opened = null;
    var results = [];
    try {
        app.displayDialogs = DialogModes.NO;
        sentinel = app.documents.add(UnitValue(8, 'px'), UnitValue(8, 'px'), 72, 'unrelated_test_document');
        var sentinelId = sentinel.id;
        var cases = ['jpg', 'tif', 'report_failure', 'cancel'];
        for (var caseIndex = 0; caseIndex < cases.length; caseIndex++) {
            var caseName = cases[caseIndex];
            var extension = caseName === 'jpg' ? '.jpg' : '.tif';
            var caseFolder = child(root, caseName, true);
            check(caseFolder.create(), 'Case directory');
            testDoc = app.documents.add(UnitValue(40, 'px'), UnitValue(60, 'px'), 300,
                caseName, NewDocumentMode.RGB, DocumentFill.WHITE);
            var input = child(caseFolder, caseName + extension, false);
            var options = extension === '.jpg' ? new JPEGSaveOptions() : new TiffSaveOptions();
            if (extension === '.jpg') { options.quality = 12; options.formatOptions = FormatOptions.STANDARDBASELINE; }
            else { options.imageCompression = TIFFEncoding.TIFFLZW; }
            testDoc.saveAs(input, options, false, Extension.LOWERCASE);
            input = testDoc.fullName;
            var before = binaryContents(input);
            // Simulate edits already present before running the tool.
            testDoc.artLayers.add().name = 'unsaved_edit';
            var testDocId = testDoc.id;
            var outputDirectory = child(caseFolder, caseName + '_制作文件', true);
            var report = child(outputDirectory, caseName + '_输出报告.txt', false);
            if (caseName === 'report_failure') {
                check(outputDirectory.create(), 'Create output directory');
                check(new Folder(report.absoluteURI).create(), 'Create report path collision');
            }
            var cancelTest = caseName === 'cancel';
            messages = [];
            try { eval(code); } catch (error) { if (error !== testStop) { throw error; } }
            check(existsDocument(sentinelId), 'Unrelated document was closed');
            check(binaryContents(input) === before, 'Source bytes were changed');
            if (caseName === 'report_failure' || cancelTest) {
                check(existsDocument(testDocId), 'Failed/canceled input must stay open');
                if (caseName === 'report_failure') {
                    check(messages.length === 1 && messages[0].indexOf('报告生成失败') >= 0, 'Missing report failure diagnostic');
                } else { check(testDoc.resolution === 300, 'Canceled document was modified'); }
                testDoc.close(SaveOptions.DONOTSAVECHANGES); testDoc = null;
            } else {
                check(!existsDocument(testDocId), 'Successful input was not closed');
                testDoc = null;
                check(messages.length === 0, 'Unexpected alert');
                check(report.exists && report.length > 0, 'Report missing');
                var output = child(outputDirectory, caseName + '_定稿' + extension, false);
                opened = app.open(output);
                check(opened.resolution === 30 && opened.layers.length === 1, 'Output parameters changed');
                opened.close(SaveOptions.DONOTSAVECHANGES); opened = null;
            }
            opened = app.open(input);
            check(opened.resolution === 300 && opened.layers.length === 1, 'Unsaved edits leaked into source');
            opened.close(SaveOptions.DONOTSAVECHANGES); opened = null;
            results.push('PASS: ' + caseName + ' | source bytes unchanged | unrelated document preserved');
        }
        return 'Photoshop ' + app.version + '\n' + results.join('\n');
    } finally {
        if (opened) { try { opened.close(SaveOptions.DONOTSAVECHANGES); } catch (e) {} }
        if (testDoc) { try { testDoc.close(SaveOptions.DONOTSAVECHANGES); } catch (e) {} }
        if (sentinel) { try { sentinel.close(SaveOptions.DONOTSAVECHANGES); } catch (e) {} }
        if (previousDocument) { try { app.activeDocument = previousDocument; } catch (e) {} }
        app.displayDialogs = previousDialogs;
    }
}());
