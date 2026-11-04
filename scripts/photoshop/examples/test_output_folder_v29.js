// Run from the repository root: node scripts/photoshop/examples/test_output_folder_v29.js
// File mocks deliberately omit the unsupported ExtendScript File.opened property.
var fs = require('fs');
var path = require('path');
var vm = require('vm');
var assert = require('assert');
var source = fs.readFileSync(path.join(__dirname, '../jsx/large_format_batch_output_v29.jsx'), 'utf8');
new vm.Script(source);

function extract(name, nextName) {
    return source.slice(source.indexOf('function ' + name + '('), source.indexOf('function ' + nextName + '('));
}
var functions = extract('v27CheckWritableFolder', 'v27TryCloseDocument') +
    extract('v27SafeWriteUTF8', 'v27NumberText');

function setup(failure) {
    var calls = [];
    var files = [];
    function File(name) {
        this.fsName = name;
        this.exists = false;
        this.length = 0;
        this.error = '';
        this.handle = false;
        files.push(this);
    }
    File.prototype.open = function () {
        calls.push('open');
        if (failure === 'open') { this.error = 'Access denied'; return false; }
        this.exists = this.handle = true;
        return true;
    };
    File.prototype.write = function () {
        calls.push('write');
        if (failure === 'throw') { throw new Error('Disk full'); }
        if (failure === 'write') { this.error = 'Disk full'; return false; }
        this.length = 10;
        return true;
    };
    File.prototype.close = function () {
        calls.push('close');
        if (failure === 'close') { this.error = 'Close failed'; return false; }
        this.handle = false;
        return true;
    };
    File.prototype.remove = function () {
        calls.push('remove');
        if (this.handle || failure === 'remove') { this.error = 'Delete denied'; return false; }
        this.exists = false;
        return true;
    };
    var context = vm.createContext({
        File: File,
        v28JoinPath: function (folder, name) { return folder + '/' + name; },
        v27ErrorText: function (error) { return error.message; }
    });
    vm.runInContext(functions, context);
    return { context: context, calls: calls, files: files, File: File };
}

var normal = setup();
var diagnostic = {};
assert.strictEqual(normal.context.v27CheckWritableFolder('中文 100% output', diagnostic), true);
assert.deepStrictEqual(normal.calls, ['open', 'write', 'close', 'remove']);
assert.strictEqual(normal.files[0].exists, false);
assert.strictEqual(diagnostic.errorText, '');

['open', 'write', 'throw', 'close', 'remove'].forEach(function (failure) {
    var test = setup(failure);
    var detail = {};
    assert.strictEqual(test.context.v27CheckWritableFolder('output', detail), false, failure);
    assert.ok(detail.errorText.length > 0, failure + ' must explain the failure');
    if (failure === 'open') { assert.deepStrictEqual(test.calls, ['open']); }
    if (failure === 'write' || failure === 'throw') {
        assert.deepStrictEqual(test.calls, ['open', 'write', 'close', 'remove']);
        assert.strictEqual(test.files[0].exists, false);
    }
});

['write', 'throw'].forEach(function (failure) {
    var test = setup(failure);
    var report = new test.File('report.txt');
    assert.throws(function () { test.context.v27SafeWriteUTF8(report, '报告'); });
    assert.deepStrictEqual(test.calls, ['open', 'write', 'close', 'remove']);
    assert.strictEqual(report.exists, false);
});
var reportTest = setup();
var report = new reportTest.File('existing-report.txt');
report.exists = true;
assert.throws(function () { reportTest.context.v27SafeWriteUTF8(report, '报告'); });
assert.deepStrictEqual(reportTest.calls, []);
assert.strictEqual(report.exists, true);
console.log('PASS: JSX syntax; writable directory; open/write/close/delete failures; report cleanup; existing report protection.');
