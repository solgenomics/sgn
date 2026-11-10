// Tests for the browser translator (static/js/sgn-i18n.js) and the English
// SGN.t / SGN.tn fallbacks in js/source/legacy/sgn.js.
// Run by t/unit/SGN/I18NJavaScript.t, or directly:
//   node --test t/unit/SGN/i18n-runtime.test.cjs
'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '../../..');
const I18N = require(path.join(root, 'static/js/sgn-i18n.js'));
const fixture = JSON.parse(fs.readFileSync(path.join(root, 't/data/i18n/test-catalogs.json'), 'utf8'));

const copy = (value) => JSON.parse(JSON.stringify(value));

function translator(locale) {
    const catalog = fixture.catalogs[locale];
    return new I18N({
        locale,
        dir: locale === 'ar' ? 'rtl' : 'ltr',
        domain: 'sgn',
        catalogs: catalog ? [copy(catalog)] : [],
    });
}

const TRIAL = ['trials.count', '%{count} trial found', '%{count} trials found'];

test('messages, context, English fallback and placeholders', () => {
    const uk = translator('uk');
    assert.equal(uk.p('controls.save', 'Save'), 'Зберегти');
    assert.equal(uk.p('seedlots.save', 'Save'), 'Зберегти партію');
    assert.equal(uk.p('', 'Save'), 'Зберегти без контексту');
    assert.equal(uk.p('controls.save', 'Save changes'), 'Save changes');
    assert.equal(translator('en').p('controls.save', 'Save'), 'Save');

    const name = '</script><img src=x onerror=alert(1)>';
    assert.equal(uk.p('trial.named', 'Created trial %{name}.', { name }), 'Створено дослід ' + name + '.');
    assert.equal(uk.p('literal', 'Keep {braces} and %{name}.', { name: 'value' }), 'Keep {braces} and value.');
    assert.equal(uk.p('literal', 'Value: %{name}', { name: '%{other}' }), 'Value: %{other}');
    assert.throws(() => uk.p('trial.named', 'Created trial %{name}.', {}), /named variable/);
});

test('plural forms follow the language rules', () => {
    const uk = translator('uk');
    const ukrainian = { 0: 'дослідів', 1: 'дослід', 2: 'досліди', 5: 'дослідів', 11: 'дослідів', 21: 'дослід', 22: 'досліди', 101: 'дослід' };
    for (const [count, word] of Object.entries(ukrainian)) {
        assert.equal(uk.np(...TRIAL, Number(count), { count }), `Знайдено ${count} ${word}`);
    }

    const ar = translator('ar');
    for (const [count, form] of [[0, 0], [1, 1], [2, 2], [3, 3], [11, 4], [100, 5]]) {
        assert.equal(ar.np(...TRIAL, count, { count }), `ar[${form}] ${count}`);
    }

    assert.equal(translator('pt-BR').np(...TRIAL, 0, { count: 0 }), 'pt-BR[0] 0');
    assert.equal(translator('pt-PT').np(...TRIAL, 0, { count: 0 }), 'pt-PT[1] 0');
    assert.equal(uk.np('missing', '%{count} trial', '%{count} trials', 21, { count: 21 }), '21 trials');
    for (const count of [-1, 1.2, NaN, undefined, 9007199254740992]) {
        assert.throws(() => uk.np('ctx', 'one', 'many', count), /count/);
    }
});

// Plural rules as syntax trees, the form the translation tools write for the browser.
const VAR = { type: 'VAR' };
const num = (val) => ({ type: 'NUM', val });
const op = (type, left, right) => ({ type, left, right });
const ENGLISH_RULE = op('NEQ', VAR, num(1)); // n != 1

function withRule(locale, nplurals, pluralAst) {
    const catalog = copy(fixture.catalogs['pt-PT']);
    catalog.nplurals = nplurals;
    catalog.pluralAst = pluralAst;
    if (nplurals !== 2) catalog.messages = {};
    return new I18N({ locale, dir: 'ltr', domain: 'sgn', catalogs: [catalog] });
}

// Run code and return [its result, the console warnings it gave].
function withWarnings(code) {
    const warnings = [];
    const originalWarn = console.warn;
    console.warn = (text) => warnings.push(text);
    try {
        return [code(), warnings];
    } finally {
        console.warn = originalWarn;
    }
}

test('catalogs are copied and validated', () => {
    const catalog = copy(fixture.catalogs.uk);
    const uk = new I18N({ locale: 'uk', dir: 'ltr', domain: 'sgn', catalogs: [catalog] });
    catalog.messages['controls.save\x04Save'].forms[0] = 'changed';
    assert.equal(uk.p('controls.save', 'Save'), 'Зберегти');

    const broken = copy(fixture.catalogs.uk);
    broken.messages['controls.save\x04Save'].forms = [];
    const [page, warnings] = withWarnings(() => new I18N({ locale: 'uk', dir: 'ltr', domain: 'sgn', catalogs: [broken] }));
    assert.equal(page.p('controls.save', 'Save'), 'Save', 'a defective message is English');
    assert.equal(page.p('navigation.manage.menu', 'Manage'), 'Керування', 'the other messages stay translated');
    assert.equal(warnings.length, 1);
    assert.match(warnings[0], /incomplete plural forms/);
});

test('plural forms are chosen by evaluating the syntax tree', () => {
    const ukrainian = fixture.catalogs.uk.pluralAst;
    const arabic = fixture.catalogs.ar.pluralAst;
    // count: [Ukrainian form, Arabic form, English form]
    const cases = {
        0: [2, 0, 1], 1: [0, 1, 0], 2: [1, 2, 1], 3: [1, 3, 1], 5: [2, 3, 1], 11: [2, 4, 1], 12: [2, 4, 1],
        21: [0, 4, 1], 22: [1, 4, 1], 25: [2, 4, 1], 100: [2, 5, 1], 101: [0, 5, 1], 102: [1, 5, 1],
        111: [2, 4, 1], 1000000: [2, 5, 1],
    };
    for (const [count, [uk, ar, en]] of Object.entries(cases)) {
        assert.equal(I18N.evaluatePlural(ukrainian, Number(count)), uk, `Ukrainian ${count}`);
        assert.equal(I18N.evaluatePlural(arabic, Number(count)), ar, `Arabic ${count}`);
        assert.equal(I18N.evaluatePlural(ENGLISH_RULE, Number(count)), en, `English ${count}`);
    }
    const english = withRule('en-GB', 2, ENGLISH_RULE);
    assert.equal(english.np(...TRIAL, 1, { count: 1 }), 'pt-PT[0] 1');
    assert.equal(english.np(...TRIAL, 0, { count: 0 }), 'pt-PT[1] 0');
    assert.equal(english.np(...TRIAL, 2, { count: 2 }), 'pt-PT[1] 2');
});

test('logical operators and comparisons give 0 or 1, like GNU gettext', () => {
    assert.equal(I18N.evaluatePlural(op('OR', VAR, num(0)), 3), 1);
    assert.equal(I18N.evaluatePlural(op('OR', VAR, num(0)), 0), 0);
    assert.equal(I18N.evaluatePlural(op('AND', VAR, num(5)), 3), 1);
    assert.equal(I18N.evaluatePlural(op('AND', VAR, num(5)), 0), 0);
    assert.equal(I18N.evaluatePlural(op('GT', VAR, num(1)), 7), 1);
    assert.equal(I18N.evaluatePlural({ type: 'TERNARY', expr: op('EQ', VAR, num(0)), truthy: num(2), falsey: num(1) }, 0), 2);
    assert.equal(withRule('pt-PT', 2, op('OR', VAR, num(0))).np(...TRIAL, 3, { count: 3 }), 'pt-PT[1] 3');
});

test('invalid plural syntax trees are rejected', () => {
    const deep = (depth) => (depth ? { type: 'GROUP', expr: deep(depth - 1) } : VAR);
    const balanced = (depth) => (depth ? op('OR', balanced(depth - 1), balanced(depth - 1)) : VAR);
    const invalid = [
        [{ type: 'EVAL', code: 'evil()' }, /Unsupported plural AST operator/],
        [{ type: 'VAR', extra: 1 }, /Unexpected plural AST field/],
        [op('MOD', VAR, num(0)), /Plural division by zero/],
        [num(-1), /Plural count/],
        [num(1.5), /Plural count/],
        [num('01'), /Plural count/],
        [num('1.0'), /Plural count/],
        [deep(25), /Invalid or oversized plural AST/],
        [balanced(7), /Invalid or oversized plural AST/], // 255 nodes, only 7 deep
        [[VAR], /Invalid or oversized plural AST/],
        [null, /Invalid or oversized plural AST/],
    ];
    for (const [ast, error] of invalid) {
        assert.throws(() => I18N.evaluatePlural(ast, 1), error);
        // A catalog with such a rule is skipped: the page shows English.
        const [page, warnings] = withWarnings(() => withRule('pt-PT', 2, ast));
        assert.equal(page.np(...TRIAL, 2, { count: 2 }), '2 trials found');
        assert.match(warnings[0], error);
    }
    assert.equal(I18N.evaluatePlural(deep(24), 3), 3, 'the depth limit itself is allowed');
    assert.equal(I18N.evaluatePlural(balanced(6), 3), 1, '127 nodes are allowed');
    const digits = withRule('pt-PT', 2, op('NEQ', VAR, num('1')));
    assert.equal(digits.np(...TRIAL, 2, { count: 2 }), 'pt-PT[1] 2', 'a constant may be a string of decimal digits');
    assert.match(withWarnings(() => withRule('pt-PT', 2, num(5)))[1][0], /Plural index outside catalog forms/);
    assert.match(withWarnings(() => withRule('pt-PT', 7, ENGLISH_RULE))[1][0], /Invalid plural form count/);
});

test('the runtime works where eval is not allowed', () => {
    const sandbox = { console };
    vm.createContext(sandbox, { codeGeneration: { strings: false, wasm: false } });
    vm.runInContext(fs.readFileSync(path.join(root, 'static/js/sgn-i18n.js'), 'utf8'), sandbox);
    assert.equal(sandbox.SGN.t('ctx', 'English'), 'English');
    sandbox.payload = { locale: 'uk', dir: 'ltr', domain: 'sgn', catalogs: [copy(fixture.catalogs.uk)] };
    assert.equal(
        vm.runInContext('new SGN.I18N(payload).np("trials.count", "%{count} trial found", "%{count} trials found", 22, {count: 22})', sandbox),
        'Знайдено 22 досліди');
});

test('native language name and requested regional tag', () => {
    assert.equal(new I18N().languageName, 'English');
    const payload = { locale: 'uk', requestedLocale: 'uk-UA', dir: 'ltr', domain: 'sgn', catalogs: [copy(fixture.catalogs.uk)] };
    const uk = new I18N({ ...payload, languageName: 'Українська' });
    assert.equal(uk.languageName, 'Українська');
    assert.equal(uk.locale, 'uk');
    assert.equal(uk.requestedLocale, 'uk-UA');
    for (const languageName of ['', ' ', 'x'.repeat(201), 'bad\nname', {}]) {
        assert.throws(() => new I18N({ ...payload, languageName }), /native language name/);
    }
    assert.throws(() => new I18N({ ...payload, requestedLocale: '../uk' }), /requested locale/);
});

test('SGN.t and SGN.tn use the current page catalog', () => {
    const page = {};
    I18N.install(page);
    assert.equal(page.SGN.t('name', 'Name: %{name}', { name: 'A&B' }), 'Name: A&B');
    assert.equal(page.SGN.tn('count', '%{count} trial', '%{count} trials', 0, { count: 0 }), '0 trials');
    page.SGN.i18n = translator('uk');
    assert.equal(page.SGN.t('controls.save', 'Save'), 'Зберегти');
    assert.equal(page.SGN.tn(...TRIAL, 22, { count: 22 }), 'Знайдено 22 досліди');
    delete page.SGN.i18n;
    assert.equal(page.SGN.t('controls.save', 'Save'), 'Save');
});

test('with translation off, sgn.js gives English SGN.t and SGN.tn', () => {
    const sandbox = { jQuery() {}, JSAN: { use() {} } };
    vm.createContext(sandbox);
    vm.runInContext(fs.readFileSync(path.join(root, 'js/source/legacy/sgn.js'), 'utf8'), sandbox);
    assert.equal(sandbox.SGN.t('caption', 'Name: %{name}', { name: '<img> & %{other}' }), 'Name: <img> & %{other}');
    for (const count of [0, 1, 2, 21]) {
        assert.equal(sandbox.SGN.tn('count', '%{count} trial', '%{count} trials', count, { count }),
            `${count} ${count === 1 ? 'trial' : 'trials'}`);
    }
    assert.throws(() => sandbox.SGN.t('caption', '%{name}', {}), /named variable/);
    assert.throws(() => sandbox.SGN.tn('count', 'One', 'Many', -1), /count/);
});

test('sgn.js keeps the translating SGN.t when the runtime loaded first', () => {
    const sandbox = { jQuery() {}, JSAN: { use() {} } };
    vm.createContext(sandbox);
    vm.runInContext(fs.readFileSync(path.join(root, 'static/js/sgn-i18n.js'), 'utf8'), sandbox);
    sandbox.payload = { locale: 'uk', dir: 'ltr', domain: 'sgn', catalogs: [copy(fixture.catalogs.uk)] };
    vm.runInContext('SGN.i18n = new SGN.I18N(payload);', sandbox);
    vm.runInContext(fs.readFileSync(path.join(root, 'js/source/legacy/sgn.js'), 'utf8'), sandbox);
    assert.equal(sandbox.SGN.t('navigation.login.sign_in', 'Login'), 'Увійти');
});

test('a translation that fails for one call gives English, as in Perl', () => {
    const rule = { type: 'TERNARY', expr: op('EQ', VAR, num(5000)), truthy: num(7), falsey: num(0) };
    let [text, warnings] = withWarnings(() => withRule('pt-PT', 2, rule).np(...TRIAL, 5000, { count: 5000 }));
    assert.equal(text, '5000 trials found');
    assert.match(warnings[0], /Plural index outside catalog forms/);
    const division = op('MOD', VAR, op('NEQ', VAR, num(5000)));
    [text, warnings] = withWarnings(() => withRule('pt-PT', 2, division).np(...TRIAL, 5000, { count: 5000 }));
    assert.equal(text, '5000 trials found');
    assert.match(warnings[0], /Plural division by zero/);

    // The English plural has no placeholder, the translated form has one.
    const catalog = copy(fixture.catalogs.uk);
    catalog.messages['files\x04%{name} file'] = { plural: 'files', forms: ['%{name}', '%{name}', '%{name}'] };
    const uk = new I18N({ locale: 'uk', dir: 'ltr', domain: 'sgn', catalogs: [catalog] });
    [text, warnings] = withWarnings(() => uk.np('files', '%{name} file', 'files', 2, {}));
    assert.equal(text, 'files');
    assert.match(warnings[0], /named variable: name/);
    assert.throws(() => uk.np('files', '%{name} file', 'files', 1, {}), /named variable/, 'a caller error still throws');
    [, warnings] = withWarnings(() => { for (let i = 0; i < 100; i++) uk.np('files', '%{name} file', 'files', 2, {}); });
    assert.equal(warnings.length, 0, 'the same failure is reported once per page');
});

test('a translation with an unknown placeholder is dropped, not shown', () => {
    const catalog = copy(fixture.catalogs.uk);
    catalog.messages['navigation.manage.menu\x04Manage'] = { plural: null, forms: ['Menu %{oops}'] };
    catalog.messages['trial.named\x04Created trial %{name}.'] = { plural: null, forms: ['%{name} %{name}'] };
    catalog.messages['trials.count\x04%{count} trial found'].forms[1] = '%{count} %{total}';
    const [uk, warnings] = withWarnings(() => new I18N({ locale: 'uk', dir: 'ltr', domain: 'sgn', catalogs: [catalog] }));
    assert.equal(uk.p('navigation.manage.menu', 'Manage'), 'Manage');
    assert.equal(uk.p('trial.named', 'Created trial %{name}.', { name: 'T1' }), 'T1 T1');
    assert.equal(uk.np(...TRIAL, 2, { count: 2 }), '2 trials found');
    assert.equal(uk.p('controls.save', 'Save'), 'Зберегти');
    assert.equal(warnings.length, 2);
    assert.match(warnings[0], /unknown placeholder %\{(oops|total)\}/);
});

test('AJAX requests to the same site send the page language', () => {
    let prefilter;
    const jQuery = { ajaxPrefilter(callback) { prefilter = callback; } };
    const page = { SGN: {} };
    I18N.sendLocaleWithAjax(jQuery, page);
    const send = (options) => {
        const headers = {};
        prefilter(options, options, { setRequestHeader(name, value) { headers[name] = value; } });
        return headers;
    };
    assert.deepEqual(send({ crossDomain: false }), {}, 'no header before the page catalog is loaded');
    page.SGN.i18n = new I18N({ locale: 'uk', requestedLocale: 'uk-UA', dir: 'ltr', domain: 'sgn', catalogs: [copy(fixture.catalogs.uk)] });
    assert.deepEqual(send({ crossDomain: false }), { 'X-SGN-Locale': 'uk' }, 'the language actually shown');
    assert.deepEqual(send({ crossDomain: true }), {}, 'no header for other sites');
});
