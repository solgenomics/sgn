'use strict';
// Owned unit fixture: real native List methods/click handlers, isolated AJAX
// responses. Browser/API acceptance against disposable SGN remains separate.
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const I18N = require('../../../static/js/sgn-i18n.js');
const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'i18n-fixtures.json'), 'utf8'));
const source = fs.readFileSync(path.join(__dirname, '../../../js/source/legacy/CXGN/List.js'), 'utf8');
const biologicalNames = ['𝛂 <em>Accession</em> & "A"', 'Stock/%{name}'];
const biologicalData = biologicalNames.join('\n') + '\n';
const listName = 'Селекція <b>2026</b> & "%{name}"';

function translator(locale = 'uk', stress = false) {
    const catalog = JSON.parse(JSON.stringify(fixture.catalogs[locale]));
    catalog.messages = {};
    const singular = (context, english, translated) => {
        catalog.messages[context + '\u0004' + english] = {plural: null, forms: [translated]};
    };
    const plurals = (context, one, many, stem) => {
        catalog.messages[context + '\u0004' + one] = {
            plural: many,
            forms: Array.from({length: catalog.nplurals}, (_, i) => stem + '[' + i + '] %{count}')
        };
    };
    const unsafe = stress ? '<img src=x onerror=alert(1) data-list-injection> & "' : '';
    singular('lists.copy.new_name', 'New list...', unsafe + 'Новий список...');
    singular('lists.copy.add_new', 'add to new list', unsafe + 'додати до нового списку');
    singular('lists.copy.add_existing', 'add to list', unsafe + 'додати до списку');
    singular('lists.new.name_required', 'Please provide a name for the new list.', 'Укажіть назву нового списку.');
    singular('lists.new.name_exists', 'A list with name "%{name}" already exists. Please choose another list name.', 'Список "%{name}" уже існує. Укажіть іншу назву.');
    singular('lists.copy.no_items', 'There are no items to add to the list.', 'Немає елементів для додавання до списку.');
    const oneNew = 'Added %{count} list element to the new list "%{name}".';
    const manyNew = 'Added %{count} list elements to the new list "%{name}".';
    catalog.messages['lists.copy.added_new\u0004' + oneNew] = {
        plural: manyNew,
        forms: Array.from({length: catalog.nplurals}, (_, i) => 'new[' + i + '] %{count} "%{name}"')
    };
    plurals('lists.copy.added_existing', 'Added %{count} list element.', 'Added %{count} list elements.', 'existing');
    return new I18N({locale, dir: locale === 'ar' ? 'rtl' : 'ltr', domain: 'sgn', catalogs: [catalog]});
}

function setup(runtime, overrides = {}, pageMetadata = {}) {
    const elements = new Map(), calls = [], alerts = [];
    const element = selector => {
        selector = String(selector).replace(/^textarea#/, '#');
        if (!elements.has(selector)) elements.set(selector, {value: '', html: '', tagName: 'DIV', click: null});
        return elements.get(selector);
    };
    element('#owned_data').value = biologicalData;
    element('#owned_data').tagName = 'TEXTAREA';
    const jq = selector => ({
        html(value) { const e = element(selector); if (arguments.length) { e.html = value; return this; } return e.html; },
        val(value) { const e = element(selector); if (arguments.length) { e.value = value; return this; } return e.value; },
        get() { return element(selector); },
        click(handler) { if (handler) { element(selector).click = handler; return this; } return element(selector).click(); },
        on() { return this; }, ready() { return this; }
    });
    jq.ajax = options => {
        calls.push({url: options.url, method: options.method || 'GET', data: JSON.parse(JSON.stringify(options.data || {})), headers: JSON.parse(JSON.stringify(options.headers || {}))});
        const handler = overrides[options.url];
        if (handler) return handler(options);
        if (options.url === '/list/available') return options.success([[101, listName, '', 2, '', 'accessions']]);
        if (options.url === '/list/available_public') return options.success([]);
        if (options.url === '/list/exists') return options.success({list_id: null});
        if (options.url === '/list/new') return options.success({list_id: 202});
        if (options.url === '/list/add/bulk') return options.success({success: 2});
        if (options.url === '/list/type/202/accessions') return options.success({success: 1});
        throw new Error('Unexpected native API request ' + options.url);
    };
    const sandbox = {window: {location: {href: 'http://127.0.0.1:18321/search/stocks', origin: 'http://127.0.0.1:18321'}}, URL,
        document: {documentElement: {getAttribute: name => name === 'data-sgn-locale' ? pageMetadata.requested || null : null, lang: pageMetadata.lang || ''}},
        CXGN: function() {}, jQuery: jq, alert: value => alerts.push(String(value)), console};
    if (runtime) sandbox.window.SGN = {i18n: runtime};
    vm.createContext(sandbox);
    vm.runInContext(source, sandbox, {filename: 'native-List.js'});
    sandbox.addToListMenu('owned_menu', 'owned_data', {listType: 'accessions', listName});
    element('#owned_data_new_list_name').value = listName;
    element('#owned_data_list_type').value = 'accessions';
    element('#owned_data_addition_type').value = 'undefined';
    element('#owned_data_list_select').value = '101';
    return {sandbox, jq, element, calls, alerts};
}

test('real native new-list click preserves names, list type and bulk data payload', () => {
    const s = setup(translator());
    s.jq('#owned_data_add_to_new_list').click();
    assert.deepEqual(s.calls.filter(c => !c.url.startsWith('/list/available')).map(({headers, ...machine}) => machine), [
        {url: '/list/exists', method: 'GET', data: {name: listName}},
        {url: '/list/new', method: 'GET', data: {name: listName}},
        {url: '/list/add/bulk', method: 'POST', data: {list_id: 202, elements: biologicalNames.join('\t') + '\t'}},
        {url: '/list/type/202/accessions', method: 'GET', data: {}}
    ]);
    assert.equal(s.sandbox.getData('owned_data'), biologicalData);
    for (const call of s.calls) assert.deepEqual(call.headers, {'X-SGN-Locale': 'uk'});
    assert.deepEqual(s.alerts, ['new[1] 2 "' + listName + '"']);
});

test('existing-list click keeps canonical selected ID and literal duplicate names', () => {
    const s = setup(translator(), {'/list/add/bulk': o => o.success({success: 1, duplicates: [biologicalNames[0]]})});
    s.jq('#owned_data_button').click();
    const {headers, ...machine} = s.calls.at(-1);
    assert.deepEqual(machine, {url: '/list/add/bulk', method: 'POST', data: {list_id: '101', elements: biologicalNames.join('\t') + '\t'}});
    assert.deepEqual(headers, {'X-SGN-Locale': 'uk'});
    assert(!s.calls.some(c => c.url === '/list/new' || c.url.startsWith('/list/type/')));
    assert.equal(s.alerts[0], 'The following item is already in the list and was not added: ' + biologicalNames[0] + '.');
    assert.equal(s.alerts[1], 'existing[0] 1');
});

test('native count notices use qualified Ukrainian and Arabic plural forms', () => {
    for (const [locale, counts] of [['uk', [[0, 2], [1, 0], [2, 1], [5, 2], [21, 0]]],
                                  ['ar', [[0, 0], [1, 1], [2, 2], [3, 3], [11, 4], [100, 5]]]]) {
        for (const [count, form] of counts) {
            const s = setup(translator(locale), {'/list/add/bulk': o => o.success({success: count})});
            s.jq('#owned_data_button').click();
            assert.deepEqual(s.alerts, ['existing[' + form + '] ' + count]);
        }
    }
});

test('optional-runtime English fallback formats parameters once and handles plurals', () => {
    const s = setup(undefined, {'/list/add/bulk': o => o.success({success: 1})});
    s.jq('#owned_data_add_to_new_list').click();
    assert.equal(s.alerts.at(-1), 'Added 1 list element to the new list "' + listName + '".');
    for (const call of s.calls) assert.deepEqual(call.headers, {'X-SGN-Locale': 'en'});
    const duplicate = setup(undefined, {'/list/exists': o => o.success({list_id: 101})});
    duplicate.jq('#owned_data_add_to_new_list').click();
    assert.equal(duplicate.alerts[0], 'A list with name "' + listName + '" already exists. Please choose another list name.');
    assert(!duplicate.calls.some(c => c.url === '/list/new'));
});

test('locale headers retain requested regional tag and cannot reach foreign or unreviewed URLs', () => {
    const catalog = JSON.parse(JSON.stringify(fixture.catalogs.uk));
    const regional = new I18N({locale: 'uk', requestedLocale: 'uk-UA', dir: 'ltr', domain: 'sgn', catalogs: [catalog]});
    const s = setup(regional);
    assert.deepEqual(JSON.parse(JSON.stringify(s.sandbox._sgnListLocaleHeaders('/list/new'))), {'X-SGN-Locale': 'uk-UA'});
    s.sandbox.document.documentElement = null;
    assert.deepEqual(JSON.parse(JSON.stringify(s.sandbox._sgnListLocaleHeaders('/list/new'))), {'X-SGN-Locale': 'uk-UA'}, 'Node fixtures without a document root retain runtime metadata');
    for (const url of ['https://other.invalid/list/new', '//other.invalid/list/new', '/brapi/v1/token', '/list/delete', 'javascript:alert(1)']) {
        assert.deepEqual(JSON.parse(JSON.stringify(s.sandbox._sgnListLocaleHeaders(url))), {});
    }
});

test('server language survives missing browser assets while generated notices use English fallback', () => {
    const s = setup(undefined, {}, {requested: 'uk'});
    s.jq('#owned_data_add_to_new_list').click();
    for (const call of s.calls) assert.deepEqual(call.headers, {'X-SGN-Locale': 'uk'});
    assert.equal(s.alerts.at(-1), 'Added 2 list elements to the new list "' + listName + '".');
    const htmlLanguage = setup(undefined, {}, {lang: 'ar'});
    assert.deepEqual(JSON.parse(JSON.stringify(htmlLanguage.sandbox._sgnListLocaleHeaders('/list/new'))), {'X-SGN-Locale': 'ar'});
    const documentFirst = setup(translator('uk'), {}, {requested: 'es-MX'});
    assert.deepEqual(JSON.parse(JSON.stringify(documentFirst.sandbox._sgnListLocaleHeaders('/list/new'))), {'X-SGN-Locale': 'es-MX'});
});

test('translation markup and original list names are escaped only at menu HTML sinks', () => {
    const s = setup(translator('uk', true));
    const html = s.element('#owned_menu').html;
    assert(html.includes('&lt;img src=x onerror=alert(1) data-list-injection&gt; &amp; &quot;'));
    assert(!html.includes('<img'));
    assert(html.includes('Селекція &lt;b&gt;2026&lt;/b&gt; &amp; &quot;%{name}&quot;'));
    assert.equal(s.sandbox.getData('owned_data'), biologicalData);
});

test('original empty-list creation and invalid-selection requests remain intact without false added notices', () => {
    const emptyName = setup(translator());
    emptyName.element('#owned_data_new_list_name').value = '';
    emptyName.jq('#owned_data_add_to_new_list').click();
    assert.deepEqual(emptyName.alerts, ['Укажіть назву нового списку.']);
    assert(!emptyName.calls.some(c => c.url === '/list/new'));
    assert(emptyName.calls.some(c => c.url === '/list/exists'), 'Original existence lookup remains before name validation');
    const emptyList = setup(translator(), {'/list/add/bulk': o => o.success({error: 'OWNED_DENIED_SELECTION'})});
    emptyList.element('#owned_data_list_select').value = null;
    emptyList.jq('#owned_data_button').click();
    assert.deepEqual(emptyList.alerts, ['OWNED_DENIED_SELECTION']);
    assert.deepEqual(emptyList.calls.at(-1).data, {list_id: null, elements: biologicalNames.join('\t') + '\t'}, 'Invalid selection keeps its original backend validation request');
    const emptyData = setup(translator());
    emptyData.element('#owned_data').value = '';
    emptyData.jq('#owned_data_add_to_new_list').click();
    assert.deepEqual(emptyData.alerts, ['Немає елементів для додавання до списку.']);
    assert(emptyData.calls.some(c => c.url === '/list/new'), 'Native creation of an empty list remains allowed');
    assert(emptyData.calls.some(c => c.url === '/list/type/202/accessions'), 'Original empty-list typing remains allowed');
    assert(!emptyData.calls.some(c => c.url === '/list/add/bulk'), 'Original addToList empty-text return does not call bulk API');
    for (const response of [{error: 'OWNED_SERVER_ERROR <b>literal</b>'}, {success: undefined}]) {
        const failed = setup(translator(), {'/list/add/bulk': o => o.success(response)});
        failed.jq('#owned_data_button').click();
        assert(!failed.alerts.some(text => text.startsWith('existing[')), 'Failed bulk write must not show an added-count notice');
    }
    const transport = setup(undefined, {'/list/exists': o => o.error({})});
    transport.jq('#owned_data_add_to_new_list').click();
    assert.deepEqual(transport.alerts, ['An error occurred. Cannot check whether the list exists.']);
    assert(!transport.calls.some(c => c.url === '/list/new'));
});
