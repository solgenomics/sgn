'use strict';
// Real native location/select methods and editor click handler in an owned VM.
// Isolated AJAX responses test request contracts; native HTTP/browser acceptance
// against original SGN remains a separate gate.
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const I18N = require('../../../static/js/sgn-i18n.js');
const root = path.resolve(__dirname, '../../..');
const sourcePaths = {
    locations: 'js/source/legacy/CXGN/Locations.js',
    select: 'js/source/legacy/CXGN/BreedersToolbox/HTMLSelect.js',
    editor: 'mason/breeders_toolbox/location_edit.mas'
};
const sources = Object.fromEntries(Object.entries(sourcePaths).map(([key, file]) =>
    [key, fs.readFileSync(path.join(root, file), 'utf8')]));
const editorScripts = [...sources.editor.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)];
assert.equal(editorScripts.length, 1, 'The native editor has one script block');
// Only the native server configuration expression is rendered as an owned
// synthetic token. No application handler or translation implementation is
// replaced, and no external request is sent.
const noaaToken = 'OWNED_NOAA_TOKEN';
const editorSource = editorScripts[0][1].replace(/<% \$c->config->\{noaa_ncdc_access_token\} %>/g, noaaToken);
assert(!editorSource.includes('<%'), 'Unrendered Mason expressions require a real rendered fixture');
const origin = 'http://127.0.0.1:18400';
const plain = value => JSON.parse(JSON.stringify(value));
const locationName = 'Поле 𝛂 «Південь» & <span>%{name}</span>';
const programs = ['Добір 𝛂 & <b>%{name}</b>', 'Breed/%{count} "A"'];
const canonicalPayload = {
    id: '41', name: locationName, abbreviation: 'П𝛂-17',
    country_name: "Côte d'Ivoire", country_code: 'CIV',
    programs: programs.join('&'), type: 'Field',
    latitude: '49.123456', longitude: '-0.012300', altitude: '180.50',
    noaa_station_id: 'GHCND:USC00000001'
};
const nativeLocation = {
    properties: {
        Id: 41, Name: locationName, Abbreviation: canonicalPayload.abbreviation,
        Code: canonicalPayload.country_code, Country: canonicalPayload.country_name,
        Program: programs.join(' & '), Type: canonicalPayload.type,
        Latitude: canonicalPayload.latitude, Longitude: canonicalPayload.longitude,
        Altitude: canonicalPayload.altitude, NOAAStationID: canonicalPayload.noaa_station_id
    },
    geometry: {type: 'Point', coordinates: [-0.0123, 49.123456]}
};

function runtime(locale, requestedLocale = locale) {
    return new I18N({locale, requestedLocale, dir: locale === 'ar' ? 'rtl' : 'ltr', domain: 'sgn', catalogs: []});
}

function setup({translator, requested = '', lang = '', overrides = {}} = {}) {
    const elements = new Map(), calls = [], alerts = [], confirmations = [];
    const selectedPrograms = programs.map((text, index) => ({value: String(23 + index), text, attributes: {}}));
    const countryOption = {text: 'CIV TRANSLATED COUNTRY CAPTION', attributes: {'data-canonical-country': canonicalPayload.country_name}};
    const element = selector => {
        if (selector && typeof selector === 'object') return selector;
        if (selector === '#location_country option:selected') return countryOption;
        if (!elements.has(selector)) elements.set(selector, {value: '', text: '', html: '', attributes: {}, click: null});
        return elements.get(selector);
    };
    for (const [key, value] of Object.entries(canonicalPayload)) {
        const selector = key === 'country_code' ? '#location_country' : '#location_' + key;
        element(selector).value = value;
    }
    element('#location_name').value = '  ' + locationName + '  ';
    element('#location_noaa_station_id').value = canonicalPayload.noaa_station_id;
    element('#breeding_program_select').attributes['data-canonical-empty-label'] = 'please select';
    const jq = selector => ({
        length: 0,
        html(value) { if (arguments.length) { element(selector).html = value; return this; } return element(selector).html; },
        empty() { element(selector).html = ''; return this; },
        val(value) { if (arguments.length) { element(selector).value = value; return this; } return element(selector).value; },
        text(value) { if (arguments.length) { element(selector).text = value; return this; } return element(selector).text; },
        attr(name, value) { if (arguments.length > 1) { element(selector).attributes[name] = value; return this; } return element(selector).attributes[name]; },
        prop() { return this; }, on() { return this; }, modal() { return this; },
        click(handler) { element(selector).click = handler; return this; },
        ready(handler) { handler(); return this; },
        each(handler) {
            const selected = selector === '#breeding_program_select option:selected' ? selectedPrograms : [];
            selected.forEach((option, index) => handler.call(option, index, option));
            return this;
        }
    });
    jq.ajax = function(options) {
        calls.push({url: options.url, method: options.type || options.method || 'GET',
            data: plain(options.data || {}), headers: plain(options.headers || {})});
        if (options.beforeSend) options.beforeSend();
        if (overrides[options.url]) return overrides[options.url](options);
        if (options.url === '/ajax/location/all') {
            options.success({data: [plain(nativeLocation), {properties: {Id: 99, Name: '[Computation]'}}]});
        } else if (options.url === '/ajax/location/store') {
            options.success({success: 'NATIVE_STORE_RESPONSE'});
        } else if (options.url === '/ajax/location/delete/41') {
            options.success({success: 'NATIVE_DELETE_RESPONSE'});
        } else if (options.url.startsWith('/ajax/html/select/')) {
            options.success({select: '<select id="owned_select"></select>'});
        } else if (options.url === 'https://www.ncdc.noaa.gov/cdo-web/api/v2/stations/' + canonicalPayload.noaa_station_id) {
            options.success({name: 'NOAA 𝛂 <station> & "%{name}"'});
        } else {
            throw new Error('Unexpected native AJAX request ' + options.url);
        }
        return {};
    };
    jq.ajaxSetup = jq.ajaxPrefilter = () => { throw new Error('Locale transport must not install a global AJAX hook'); };
    const sandbox = {
        window: {location: {href: origin + '/breeders_toolbox/locations?lang=en', origin}},
        URL, document: {documentElement: {getAttribute: name => name === 'data-sgn-locale' ? requested : null, lang}},
        CXGN: {List: function() { this.listSelect = () => ''; }},
        jQuery: jq, $: jq, console: {log() {}},
        alert: value => alerts.push(String(value)),
        confirm: value => { confirmations.push(String(value)); return true; },
        setTimeout() {}
    };
    if (translator) sandbox.window.SGN = {i18n: translator};
    vm.createContext(sandbox);
    vm.runInContext(sources.select, sandbox, {filename: sourcePaths.select});
    vm.runInContext(sources.locations, sandbox, {filename: sourcePaths.locations});
    vm.runInContext(editorSource, sandbox, {filename: sourcePaths.editor + ':script'});
    const store = () => {
        let prevented = false;
        element('#store_location_submit').click({preventDefault() { prevented = true; }});
        assert(prevented, 'The original editor prevents native form submission');
    };
    return {sandbox, calls, alerts, confirmations, element, selectedPrograms, countryOption, store};
}

const helpers = [
    ['_sgnLocationLocaleHeaders', ['/ajax/location/all', '/ajax/location/store', '/ajax/location/delete/41']],
    ['_sgnLocationEditorLocaleHeaders', ['/ajax/location/store']],
    ['_sgnHTMLSelectLocaleHeaders', ['locations', 'breeding_programs', 'seedlots', 'material_types', 'projects', 'label_data_source_types', 'label_data_sources', 'genotyping_protocol', 'datasets', 'models', 'trials', 'genotyping_trials', 'traits'].map(type => '/ajax/html/select/' + type)]
];

test('four page languages reach real load, delete, store, and select requests without changing data', () => {
    for (const locale of ['en', 'uk', 'es', 'ar']) {
        const s = setup({translator: runtime(locale)});
        let loaded;
        s.sandbox.updateLocations(data => { loaded = plain(data); });
        s.sandbox.delete_location(41);
        s.store();
        const options = {empty: 1, id: 'owned_select', default: 'please select', multiple: 1, project_id: 23};
        s.sandbox.get_select_box('locations', 'owned_select_container', options);
        assert.deepEqual(loaded, [nativeLocation], 'Canonical location data survives the original computation-row filter');
        const internal = s.calls.filter(call => call.url.startsWith('/ajax/'));
        for (const call of internal) assert.deepEqual(call.headers, {'X-SGN-Locale': locale});
        assert.deepEqual(s.calls.find(call => call.url === '/ajax/location/store'),
            {url: '/ajax/location/store', method: 'POST', headers: {'X-SGN-Locale': locale}, data: canonicalPayload});
        assert.deepEqual(s.calls.find(call => call.url === '/ajax/location/delete/41'),
            {url: '/ajax/location/delete/41', method: 'POST', headers: {'X-SGN-Locale': locale}, data: {}});
        assert.deepEqual(s.calls.find(call => call.url === '/ajax/html/select/locations').data, options);
        assert.deepEqual(s.calls[0].data, {empty: 1, id: 'breeding_program_select', default: 'please select', multiple: 1});
        assert.equal(s.confirmations[0], 'Are you sure you want to delete location ' + locationName + '? ');
        assert(s.alerts.includes('NATIVE_STORE_RESPONSE') && s.alerts.includes('NATIVE_DELETE_RESPONSE'),
            'Server notices remain server-owned data');
    }
});

test('native NOAA station check keeps its token-only header and exact station URL', () => {
    const s = setup({translator: runtime('uk', 'uk-UA'), requested: 'es-MX', lang: 'ar'});
    s.store();
    const external = s.calls.filter(call => !call.url.startsWith('/'));
    assert.deepEqual(external, [{
        url: 'https://www.ncdc.noaa.gov/cdo-web/api/v2/stations/' + canonicalPayload.noaa_station_id,
        method: 'GET', data: {}, headers: {token: noaaToken}
    }]);
    assert.deepEqual(s.calls.find(call => call.url === '/ajax/location/store').headers, {'X-SGN-Locale': 'es-MX'});
    assert(s.alerts.includes('Found NOAA Station from given NOAA StationID: NOAA 𝛂 <station> & "%{name}"'));
});

test('requested regional page language outranks effective content language at native call sites', () => {
    const s = setup({translator: runtime('uk', 'uk-UA'), lang: 'uk'});
    s.sandbox.updateLocations(() => {});
    s.store();
    for (const call of s.calls.filter(call => call.url.startsWith('/ajax/'))) {
        assert.deepEqual(call.headers, {'X-SGN-Locale': 'uk-UA'});
    }
    s.sandbox.document.documentElement.getAttribute = () => 'ar-EG';
    s.sandbox.updateLocations(() => {});
    assert.deepEqual(s.calls.at(-1).headers, {'X-SGN-Locale': 'ar-EG'}, 'The current page metadata is read for every request');
});

test('missing optional browser assets retain server page language and whole English notices', () => {
    const s = setup({requested: 'uk-UA', lang: 'uk', overrides: {'/ajax/location/store': options => options.error({})}});
    s.store();
    for (const call of s.calls) assert.deepEqual(call.headers, {'X-SGN-Locale': 'uk-UA'});
    assert.deepEqual(s.alerts, ['An error occurred while storing the location details. Please try again later.']);
    s.element('#location_name').value = '';
    const before = s.calls.length;
    s.store();
    assert.equal(s.calls.length, before, 'Original required-name validation still stops the request');
    assert.equal(s.alerts.at(-1), 'A location name is required.');
    const fallback = setup();
    fallback.store();
    for (const call of fallback.calls.filter(call => call.url.startsWith('/ajax/'))) {
        assert.deepEqual(call.headers, {'X-SGN-Locale': 'en'});
    }
});

test('all three native helpers honor the complete page/runtime metadata priority', () => {
    const s = setup({translator: runtime('uk', 'uk-UA'), requested: 'es-MX', lang: 'ar'});
    const check = expected => {
        for (const [name, urls] of helpers) for (const url of urls) {
            assert.deepEqual(plain(s.sandbox[name](url)), {'X-SGN-Locale': expected}, name + ': ' + url);
        }
    };
    check('es-MX');
    s.sandbox.document.documentElement.getAttribute = () => '';
    check('uk-UA');
    delete s.sandbox.window.SGN.i18n.requestedLocale;
    check('ar');
    s.sandbox.document.documentElement.lang = '';
    check('uk');
    delete s.sandbox.window.SGN;
    check('en');
    s.sandbox.window.SGN = {i18n: runtime('uk', 'uk-UA')};
    delete s.sandbox.document;
    check('uk-UA');
});

test('reviewed same-origin URLs alone receive a locale header; foreign and invalid routes never do', () => {
    const s = setup({translator: runtime('ar')});
    for (const [name, urls] of helpers) {
        for (const url of urls) {
            for (const reviewed of [url, url + '?owned=1', origin + url, '//127.0.0.1:18400' + url]) {
                assert.deepEqual(plain(s.sandbox[name](reviewed)), {'X-SGN-Locale': 'ar'});
            }
            for (const foreign of ['https://other.invalid' + url, '//other.invalid' + url,
                'http://127.0.0.1:18401' + url, 'https://127.0.0.1:18400' + url]) {
                assert.deepEqual(plain(s.sandbox[name](foreign)), {});
            }
        }
        for (const url of ['http://[::1', 'javascript:alert(1)', '/brapi/v1/token', '/ajax/unrelated',
            '/ajax/location/delete/not-a-number', '/ajax/location/delete/41/extra', '/ajax/location/store/extra',
            '/ajax/html/select/locations/extra', '/ajax/html/select/unreviewed_type', '/ajax/location/all-other']) {
            assert.deepEqual(plain(s.sandbox[name](url)), {}, name + ' must exclude ' + url);
        }
        assert.deepEqual(plain(s.sandbox[name]({toString() { throw new Error('Owned malformed URL'); }})), {});
    }
    assert.deepEqual(plain(s.sandbox._sgnLocationEditorLocaleHeaders('/ajax/location/all')), {});
    assert.deepEqual(plain(s.sandbox._sgnHTMLSelectLocaleHeaders('/ajax/location/store')), {});
    assert.deepEqual(plain(s.sandbox._sgnLocationLocaleHeaders('/ajax/html/select/locations')), {});
    s.sandbox.get_select_box('unreviewed_type', 'owned_unreviewed_select', {id: 'owned_trait'});
    assert.deepEqual(s.calls.at(-1).headers, {}, 'An unreviewed native select remains callable without locale transport');
});

test('unavailable URL parsing cannot break native requests or contaminate external NOAA headers', () => {
    const s = setup({requested: 'ar', lang: 'ar'});
    s.sandbox.URL = undefined;
    for (const [name, urls] of helpers) for (const url of urls) assert.deepEqual(plain(s.sandbox[name](url)), {});
    s.sandbox.updateLocations(() => {});
    s.store();
    assert.deepEqual(s.calls.findLast(call => call.url === '/ajax/location/store').data, canonicalPayload);
    assert.deepEqual(s.calls.findLast(call => call.url === '/ajax/location/store').headers, {});
    assert.deepEqual(s.calls.at(-1).headers, {token: noaaToken});
});

test('translated empty program selection still sends the original canonical default', () => {
    const s = setup({translator: runtime('es')});
    s.selectedPrograms.splice(0, s.selectedPrograms.length, {value: '', text: 'seleccione', attributes: {}});
    s.store();
    const stored = s.calls.find(call => call.url === '/ajax/location/store').data;
    assert.deepEqual(stored, {...canonicalPayload, programs: 'please select'});
    s.countryOption.attributes = {};
    s.countryOption.text = "CIV Côte d'Ivoire";
    s.store();
    assert.deepEqual(s.calls.findLast(call => call.url === '/ajax/location/store').data,
        {...canonicalPayload, programs: 'please select'}, 'Original source-country caption fallback stays compatible');
});
