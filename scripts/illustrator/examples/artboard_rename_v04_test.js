/* Run from repository root: node scripts/illustrator/examples/artboard_rename_v04_test.js */
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const path = require('path');
const source = fs.readFileSync(path.join(__dirname, '../jsx/artboard_rename_v04.jsx'), 'utf8').replace(/^#target.*$/m, '');
// Exercise the actual JSX helpers without starting Illustrator or changing documents.
const context = {};
vm.createContext(context);
vm.runInContext(source.replace('try { main(); }', 'this.api = { dimensions: dimensions, makeName: makeName, indices: indices, positive: positive, applyPlan: applyPlan, uniqueNames: uniqueNames }; try { }'), context);
const a = context.api;
const rect = [0, 200 * 72 / 25.4, 80 * 72 / 25.4, 0];
assert.equal(a.dimensions(rect, 10, 'mm').text, '800×2000mm');
assert.equal(a.dimensions(rect, 100, 'cm').text, '800×2000cm');
assert.equal(a.dimensions(rect, 100, 'm').text, '8×20m');
assert.equal(a.dimensions([10, -10, 110, -60], 1, 'px').text, '100×50px');
assert.equal(a.dimensions(rect, 1, 'm').zero, true);
assert.equal(a.dimensions([0, 28.5, 12.5, 0], 1, 'px').text, '13×29px');
assert.equal(a.dimensions(rect.map(n => n / 10), 10 * 10, 'mm').text, '800×2000mm');
const expected = ['01_展架_800×2000mm', '01_展架', '01_800×2000mm', '展架_800×2000mm', '01', '展架', '800×2000mm'];
for (let mode = 0; mode < 7; mode++) assert.equal(a.makeName(mode, '展架', '800×2000mm', 1, 99), expected[mode]);
for (const [index, count, serial] of [[1,1,'01'],[9,99,'09'],[99,99,'99'],[1,100,'001'],[9,100,'009'],[99,100,'099'],[100,100,'100'],[999,1000,'999'],[1000,1000,'1000']]) {
    assert.equal(a.makeName(4, '', '', index, count), serial);
    assert.equal(a.makeName(0, '中文@#$（正面）!', '10×20px', index, count), serial + '_中文@#$（正面）!_10×20px');
}
assert.throws(() => a.makeName(7, '', '', 1, 1));
assert.equal(a.indices('3,1，2-4,3', 5).join(','), '0,1,2,3');
for (const input of ['0', '6', '3-1', '', '1,,2', '1.5']) assert.throws(() => a.indices(input, 5));
for (const input of ['0', '-2', 'NaN', '1e3', '1:10', '']) assert.throws(() => a.positive(input));
assert.equal(a.positive(' 0.5 '), 0.5);
assert.throws(() => a.dimensions(rect, Infinity, 'mm'));
const boards = [{name:'甲'}, {name:'乙'}];
const plan = [{index:0, before:'甲', after:'新甲'}, {index:1, before:'乙', after:'新乙'}];
assert.equal(a.applyPlan(boards, plan), 2);
assert.equal(boards[1].name, '新乙');
assert.equal(a.applyPlan(boards, [{index:0, before:'新甲', after:'新甲'}]), 0);
let second = '乙';
const failing = [{name:'甲'}, {get name() { return second; }, set name(n) { if (n === '新乙') throw Error('write failed'); second = n; }}];
assert.throws(() => a.applyPlan(failing, plan), /已恢复/);
assert.equal(failing[0].name, '甲');
assert.equal(second, '乙');
const unrecoverable = [{get name() { return '甲'; }, set name(value) { throw Error('locked'); }}];
assert.throws(() => a.applyPlan(unrecoverable, plan.slice(0, 1)), /未能恢复.*1/);
function renameCase(old, bases, targets = bases.map((_, i) => i)) {
    const boards = old.map(name => ({name}));
    const plan = bases.map((after, i) => ({index:targets[i], before:old[targets[i]], after}));
    const numbered = a.uniqueNames(boards, plan);
    // Preview must not mutate the document.
    assert.deepEqual(boards.map(b => b.name), old);
    a.applyPlan(boards, plan);
    const names = boards.map(b => b.name);
    assert.equal(new Set(names).size, names.length);
    return {names, numbered};
}
assert.deepEqual(renameCase(['甲','乙','丙'], ['展架','展架','展架']).names, ['展架-A','展架-B','展架-C']);
assert.deepEqual(renameCase(['甲','乙','丙'], ['展架','展架','展架-A']).names, ['展架-B','展架-C','展架-A']);
assert.deepEqual(renameCase(['甲','展架','展架-A'], ['展架']).names, ['展架-B','展架','展架-A']);
assert.deepEqual(renameCase(['甲','乙'], ['乙','甲']).names, ['乙','甲']);
assert.deepEqual(renameCase(['展架-A','展架-B'], ['展架','展架']).names, ['展架-A','展架-B']);
assert.equal(renameCase(['甲','乙'], ['唯一甲','唯一乙']).numbered, 0);
assert.deepEqual(renameCase(['甲','甲','乙'], ['新甲','新甲'], [0,1]).names, ['新甲-A','新甲-B','乙']);
assert.throws(() => renameCase(['甲','重复','重复'], ['新甲']), /未处理画板中存在同名/);
assert.deepEqual(renameCase(['甲','乙','丙'], ['__proto__','__proto__','constructor']).names, ['__proto__-A','__proto__-B','constructor']);
for (let mode = 0; mode < 7; mode++) {
    const base = a.makeName(mode, '中文（正面）!', '800×2000mm', 1, 2);
    assert.deepEqual(renameCase(['甲','乙'], [base, base]).names, [base+'-A',base+'-B']);
}
const many = renameCase(Array.from({length:1000}, (_, i) => '旧'+i), Array(1000).fill('尺寸'));
assert.equal(many.names[999], '尺寸-ALL');
assert.equal(many.numbered, 1000);
const helpLiteral = source.match(/help\.onClick = function \(\) \{\s*alert\(("(?:[^"\\]|\\.)*")/)[1];
assert(JSON.parse(helpLiteral).endsWith('\n\n作者：Even Wu\n联系作者：huaping.woo@gmail.com'));
for (const [number, suffix] of [[1,'A'],[26,'Z'],[27,'AA'],[28,'AB'],[52,'AZ'],[53,'BA'],[133,'EC'],[702,'ZZ'],[703,'AAA'],[1000,'ALL']]) {
    assert.equal(many.names[number - 1], '尺寸-' + suffix);
}
console.log('PASS: seven modes, 99/100 digit boundary, 1000 names, collisions, dimensions, scope, rollback and attribution.');
