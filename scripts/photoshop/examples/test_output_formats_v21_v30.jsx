// Photoshop native integration test. Uses only newly created documents and a unique work folder.
(function () {
    var exampleFolder = new File($.fileName).parent;
    var repository = exampleFolder.parent.parent.parent;
    function readScript(name) {
        var file = new File(exampleFolder.parent.absoluteURI + '/jsx/' + name);
        file.encoding = 'UTF-8';
        if (!file.open('r')) { throw new Error('Cannot read ' + name); }
        var text = file.read();
        file.close();
        return text;
    }
    var singleScript = readScript('large_format_single_file_process_v21.jsx')
        .replace(/^#target photoshop/, '').replace('app.bringToFront();', '')
        .replace('preview.show();', 'run=true;').replace(/alert\(/g, 'testAlert(');
    var batchScript = readScript('large_format_batch_output_v30.jsx');
    eval(batchScript.slice(batchScript.indexOf('function v27SaveProductionFile('), batchScript.indexOf('function v27SafeWriteUTF8(')));
    function v27ErrorText(error) { return error.message || String(error); }
    function testAlert(message) { throw new Error(message); }
    function check(condition, message) { if (!condition) { throw new Error(message); } }
    function checkAlpha(document) {
        var descriptor = new ActionDescriptor();
        var selection = new ActionReference();
        selection.putProperty(charIDToTypeID('Chnl'), charIDToTypeID('fsel'));
        descriptor.putReference(charIDToTypeID('null'), selection);
        var transparency = new ActionReference();
        transparency.putEnumerated(charIDToTypeID('Chnl'), charIDToTypeID('Chnl'), charIDToTypeID('Trsp'));
        descriptor.putReference(charIDToTypeID('T   '), transparency);
        executeAction(charIDToTypeID('setd'), descriptor, DialogModes.NO);
        var channel = document.channels.add();
        document.selection.store(channel);
        document.selection.deselect();
        var histogram = channel.histogram;
        channel.remove();
        document.selection.deselect();
        var partial = 0;
        for (var bin = 1; bin < 255; bin++) { partial += histogram[bin]; }
        check(histogram[0] === 1475 && histogram[255] === 525 && partial === 400,
            'Alpha pixel counts: ' + histogram[0] + '/' + histogram[255] + '/' + partial);
    }
    function child(parent, name, isFolder) {
        var uri = parent.absoluteURI + '/' + encodeURIComponent(name);
        return isFolder ? new Folder(uri) : new File(uri);
    }
    var resultRoot = child(new Folder(repository.absoluteURI + '/work'), 'format_v21_v30_' + new Date().getTime(), true);
    check(resultRoot.create(), 'Cannot create test root');
    var cases = [
        { name: '透明 RGB', extension: '.TIFF', mode: NewDocumentMode.RGB, depth: BitsPerChannelType.EIGHT, transparent: true },
        { name: '透明 CMYK', extension: '.tif', mode: NewDocumentMode.CMYK, depth: BitsPerChannelType.EIGHT, transparent: true },
        { name: '透明 RGB16', extension: '.tiff', mode: NewDocumentMode.RGB, depth: BitsPerChannelType.SIXTEEN, transparent: true },
        { name: '不透明 TIFF', extension: '.tif', mode: NewDocumentMode.RGB, depth: BitsPerChannelType.EIGHT, transparent: false },
        { name: '照片 RGB', extension: '.JPEG', mode: NewDocumentMode.RGB, depth: BitsPerChannelType.EIGHT, transparent: false },
        { name: '照片 CMYK', extension: '.jpg', mode: NewDocumentMode.CMYK, depth: BitsPerChannelType.EIGHT, transparent: false }
    ];
    var priorDialogs = app.displayDialogs;
    var priorDocument = app.documents.length ? app.activeDocument : null;
    var testDoc = null;
    var reopened = null;
    var results = [];
    try {
        app.displayDialogs = DialogModes.NO;
        for (var caseIndex = 0; caseIndex < cases.length; caseIndex++) {
            var item = cases[caseIndex];
            var caseFolder = child(resultRoot, item.name, true);
            check(caseFolder.create(), 'Case directory');
            testDoc = app.documents.add(UnitValue(40, 'px'), UnitValue(60, 'px'), 300, item.name,
                item.mode, item.transparent ? DocumentFill.TRANSPARENT : DocumentFill.WHITE, 1, item.depth);
            var fillColor = new SolidColor();
            fillColor.rgb.red = 230; fillColor.rgb.green = 60; fillColor.rgb.blue = 20;
            testDoc.selection.select([[5,5], [20,5], [20,40], [5,40]]);
            testDoc.selection.fill(fillColor);
            testDoc.selection.deselect();
            var isJpg = /\.jpe?g$/i.test(item.extension);
            if (!isJpg) {
                testDoc.artLayers.add();
                testDoc.activeLayer.opacity = 50;
                testDoc.selection.select([[20,10], [30,10], [30,50], [20,50]]);
                testDoc.selection.fill(fillColor);
                testDoc.selection.deselect();
                var hiddenLayer = testDoc.artLayers.add();
                testDoc.selection.selectAll();
                testDoc.selection.fill(fillColor);
                testDoc.selection.deselect();
                hiddenLayer.visible = false;
            }
            var inputFile = child(caseFolder, item.name + item.extension, false);
            var inputOptions;
            if (isJpg) {
                inputOptions = new JPEGSaveOptions();
                inputOptions.quality = 6;
                inputOptions.formatOptions = FormatOptions.STANDARDBASELINE;
            } else {
                inputOptions = new TiffSaveOptions();
                inputOptions.imageCompression = TIFFEncoding.TIFFLZW;
                inputOptions.layers = true;
                inputOptions.transparency = true;
            }
            inputOptions.embedColorProfile = true;
            testDoc.saveAs(inputFile, inputOptions, false, Extension.LOWERCASE);
            // Photoshop may normalize the suffix case when saving.
            inputFile = testDoc.fullName;
            var originalLayers = testDoc.layers.length;
            var originalProfile = testDoc.colorProfileName;
            var originalMode = testDoc.mode;
            var originalDepth = testDoc.bitsPerChannel;
            var outputSuffix = isJpg ? '.jpg' : '.tif';
            eval(singleScript);
            check(testDoc.layers.length === originalLayers, 'Single changed source layers');
            var actualStem = decodeURIComponent(inputFile.name).replace(/\.[^.]+$/, '');
            var singleFolder = child(caseFolder, actualStem + '_制作文件', true);
            var singleFile = child(singleFolder, actualStem + '_定稿' + outputSuffix, false);
            var batchFile = child(caseFolder, 'batch' + outputSuffix, false);
            v27SaveProductionFile(testDoc, batchFile, outputSuffix);
            check(testDoc.layers.length === originalLayers, 'Batch changed source layers');
            var report = child(singleFolder, actualStem + '_输出报告.txt', false);
            report.encoding = 'UTF-8';
            check(report.open('r'), 'Cannot read report');
            var reportContent = report.read(); report.close();
            check(reportContent.indexOf('_定稿' + outputSuffix) >= 0, 'Wrong report extension');
            testDoc.close(SaveOptions.DONOTSAVECHANGES); testDoc = null;
            var outputs = [singleFile, batchFile];
            for (var outputIndex = 0; outputIndex < outputs.length; outputIndex++) {
                reopened = app.open(outputs[outputIndex]);
                check(reopened.layers.length === 1, 'Output must have one layer');
                check(reopened.width.as('px') === 40 && reopened.height.as('px') === 60, 'Pixels changed');
                check(reopened.resolution === 30, 'Wrong PPI');
                check(reopened.mode === originalMode && reopened.bitsPerChannel === originalDepth, 'Color mode/depth changed');
                check(reopened.colorProfileName === originalProfile, 'ICC changed');
                if (item.transparent) {
                    check(!reopened.layers[0].isBackgroundLayer, 'Transparency flattened into background');
                    check(reopened.layers[0].bounds[0].as('px') === 5, 'Transparent left margin lost');
                    checkAlpha(reopened);
                }
                reopened.close(SaveOptions.DONOTSAVECHANGES); reopened = null;
            }
            reopened = app.open(inputFile);
            check(reopened.resolution === 300, 'Source PPI changed');
            check(reopened.layers.length === originalLayers, 'Source layer count changed');
            reopened.close(SaveOptions.DONOTSAVECHANGES); reopened = null;
            results.push('PASS: ' + item.name + ' | single + batch | one output layer | 40x60 | 30 ppi | mode/depth/ICC preserved | source unchanged');
        }
        var summary = 'Photoshop ' + app.version + '\n' + results.join('\n');
        var log = child(resultRoot, 'verification.txt', false);
        log.encoding = 'UTF-8'; check(log.open('w'), 'Cannot write verification'); log.write(summary); log.close();
        return resultRoot.fsName + '\n' + summary;
    } finally {
        if (reopened) { try { reopened.close(SaveOptions.DONOTSAVECHANGES); } catch (e) {} }
        if (testDoc) { try { testDoc.close(SaveOptions.DONOTSAVECHANGES); } catch (e) {} }
        if (priorDocument) { try { app.activeDocument = priorDocument; } catch (e) {} }
        app.displayDialogs = priorDialogs;
    }
}());
