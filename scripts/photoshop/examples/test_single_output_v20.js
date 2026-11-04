// Run: node scripts/photoshop/examples/test_single_output_v20.js
// Execute the complete script with Photoshop/File mocks; File.opened is absent.
var fs = require('fs');
var path = require('path');
var vm = require('vm');
var assert = require('assert');
var source = fs.readFileSync(path.join(__dirname, '../jsx/large_format_single_file_process_v20.jsx'), 'utf8');
var script = new vm.Script(source.replace(/^#target photoshop/, ''));

function run(options) {
    options = options || {};
    var files = {};
    var calls = [];
    var alerts = [];
    var confirmations = [];
    var directories = {};
    var stopped = {};
    var parent = 'file:///C:/test/' + encodeURIComponent(options.name || '中文 空格 100%20');
    var stem = options.name || '画面 100%20';
    var folderURI = parent + '/' + encodeURIComponent(stem + '_制作文件');
    var tiffURI = folderURI + '/' + encodeURIComponent(stem + '_定稿.tif');
    var reportURI = folderURI + '/' + encodeURIComponent(stem + '_输出报告.txt');
    function File(uri) {
        this.absoluteURI = uri;
        this.name = uri.slice(uri.lastIndexOf('/') + 1);
        this.fsName = decodeURI(uri);
        this.parent = new Folder(uri.slice(0, uri.lastIndexOf('/')));
        this.error = '';
        this.handle = false;
        Object.defineProperty(this, 'exists', { get: function () { return Object.prototype.hasOwnProperty.call(files, uri); } });
        Object.defineProperty(this, 'length', { get: function () { return (files[uri] || '').length; } });
    }
    File.encode = encodeURI;
    File.prototype.kind = function () { return /\.tmp$/.test(this.name) ? 'probe' : 'report'; };
    File.prototype.open = function () {
        calls.push(this.kind() + ':open');
        if (options.failure === this.kind() + ':open') { this.error = 'Access denied'; return false; }
        this.handle = true;
        files[this.absoluteURI] = '';
        return true;
    };
    File.prototype.write = function (text) {
        calls.push(this.kind() + ':write');
        if (options.failure === this.kind() + ':throw') { throw new Error('Disk full'); }
        if (options.failure === this.kind() + ':write') { this.error = 'Disk full'; return false; }
        files[this.absoluteURI] += text;
        return true;
    };
    File.prototype.close = function () {
        calls.push(this.kind() + ':close');
        if (options.failure === this.kind() + ':close') { this.error = 'Close failed'; return false; }
        this.handle = false;
        return true;
    };
    File.prototype.remove = function () {
        calls.push(this.kind() + ':remove');
        if (this.handle || options.failure === this.kind() + ':remove') { this.error = 'Delete denied'; return false; }
        delete files[this.absoluteURI];
        return true;
    };
    function Folder(uri) {
        this.absoluteURI = uri;
        this.fsName = decodeURI(uri);
        Object.defineProperty(this, 'exists', { get: function () { return !!directories[uri]; } });
        this.create = function () {
            calls.push('mkdir');
            if (options.failure === 'mkdir') { this.error = 'Access denied'; return false; }
            directories[uri] = true;
            return true;
        };
    }
    var sourceFile = new File(parent + '/' + encodeURIComponent(stem + '.tif'));
    files[sourceFile.absoluteURI] = 'original source';
    if (options.existing) { files[tiffURI] = 'old tiff'; files[reportURI] = 'old report'; }
    var doc = {
        name: sourceFile.name, resolution: 300, mode: 'CMYK',
        width: { as: function () { return 10; } }, height: { as: function () { return 20; } },
        resizeImage: function (w, h, ppi, method) {
            assert.strictEqual(w, undefined); assert.strictEqual(h, undefined); assert.strictEqual(method, 'NONE');
            calls.push('resize:' + ppi); this.resolution = ppi;
        },
        saveAs: function (file, settings, copy, extension) {
            calls.push('save');
            assert.strictEqual(file.absoluteURI, tiffURI);
            assert.strictEqual(settings.imageCompression, 'LZW');
            assert.strictEqual(settings.embedColorProfile, true);
            assert.strictEqual(copy, true); assert.strictEqual(extension, 'lower');
            if (options.failure === 'save') { throw new Error('TIFF access denied'); }
            if (options.failure !== 'empty-tiff') { files[file.absoluteURI] = 'tiff'; }
        }
    };
    Object.defineProperty(doc, 'fullName', { get: function () {
        if (options.failure === 'unsaved') { throw new Error('Not saved'); }
        return sourceFile;
    } });
    var ok;
    function control() {
        return {
            add: function (kind, unused, label) { var child = control(); if (label === '确认输出') { ok = child; } return child; },
            graphics: { PenType: { SOLID_COLOR: 1 }, newPen: function () {} },
            show: function () { if (!options.cancelPreview) { ok.onClick(); } }, close: function () {}
        };
    }
    var context = vm.createContext({
        File: File, Folder: Folder, Window: control, ScriptUI: { newFont: function () {} },
        app: { bringToFront: function () {}, documents: [doc], activeDocument: doc },
        DocumentMode: { CMYK: 'CMYK' }, ResampleMethod: { NONE: 'NONE' },
        TiffSaveOptions: function () {}, TIFFEncoding: { TIFFLZW: 'LZW' }, Extension: { LOWERCASE: 'lower' },
        alert: function (text) { alerts.push(text); },
        confirm: function (text) { confirmations.push(text); return !!options.overwrite; },
        exit: function () { throw stopped; }
    });
    try { script.runInContext(context); } catch (error) { if (error !== stopped) { throw error; } }
    assert.strictEqual(files[sourceFile.absoluteURI], 'original source');
    return { files: files, calls: calls, alerts: alerts, confirmations: confirmations, doc: doc, tiffURI: tiffURI, reportURI: reportURI };
}

['English', '中文', 'with spaces', '百分比 100%20 #'].forEach(function (name) {
    var result = run({ name: name });
    assert.deepStrictEqual(result.alerts, []);
    assert.strictEqual(result.doc.resolution, 30);
    assert.strictEqual(result.files[result.tiffURI], 'tiff');
    assert.ok(result.files[result.reportURI].indexOf('\uFEFF') === 0);
    assert.ok(result.files[result.reportURI].indexOf('huaping.woo@gmail.com') >= 0);
    assert.ok(result.files[result.reportURI].indexOf(name + '_定稿.tif') >= 0);
    assert.ok(result.calls.indexOf('probe:remove') < result.calls.indexOf('resize:30'));
    assert.strictEqual(Object.keys(result.files).filter(function (key) { return /\.tmp$/.test(key); }).length, 0);
});
['unsaved', 'mkdir', 'probe:open', 'probe:write', 'probe:throw', 'probe:close', 'probe:remove'].forEach(function (failure) {
    var result = run({ failure: failure });
    assert.strictEqual(result.doc.resolution, 300, failure);
    assert.strictEqual(result.calls.indexOf('save'), -1, failure);
    assert.strictEqual(result.alerts.length, 1, failure);
    if (failure === 'probe:write' || failure === 'probe:throw') {
        assert.ok(result.calls.indexOf('probe:close') < result.calls.indexOf('probe:remove'));
    }
});
['save', 'empty-tiff'].forEach(function (failure) {
    var result = run({ failure: failure });
    assert.strictEqual(result.doc.resolution, 300);
    assert.strictEqual(result.calls.indexOf('report:open'), -1);
    assert.ok(result.alerts[0].indexOf('TIFF保存失败') >= 0);
});
['report:open', 'report:write', 'report:throw', 'report:close'].forEach(function (failure) {
    var result = run({ failure: failure });
    assert.strictEqual(result.files[result.tiffURI], 'tiff');
    assert.ok(result.alerts[0].indexOf('TIFF已保存') >= 0);
    if (failure === 'report:write' || failure === 'report:throw') {
        assert.ok(result.calls.indexOf('report:close') < result.calls.indexOf('report:remove'));
        assert.strictEqual(result.files[result.reportURI], undefined);
    }
});
var canceled = run({ existing: true });
assert.strictEqual(canceled.files[canceled.tiffURI], 'old tiff');
assert.strictEqual(canceled.files[canceled.reportURI], 'old report');
assert.strictEqual(canceled.doc.resolution, 300);
var overwrite = run({ existing: true, overwrite: true });
assert.strictEqual(overwrite.confirmations.length, 1);
assert.strictEqual(overwrite.files[overwrite.tiffURI], 'tiff');
assert.deepStrictEqual(overwrite.alerts, []);
var previewCancel = run({ cancelPreview: true });
assert.deepStrictEqual(previewCancel.calls, []);
console.log('PASS: complete JSX mock execution; encoded paths; preflight and cleanup; TIFF failure rollback; report failures; overwrite/cancel protection; original source preserved.');
