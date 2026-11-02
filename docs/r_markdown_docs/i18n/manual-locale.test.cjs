'use strict';
/** @file Browser regressions for the standalone Bookdown language navigator. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {test, before, after} = require('node:test');
const {chromium} = require('playwright');

const origin = 'https://manual-navigation.invalid';
const source = fs.readFileSync(path.join(__dirname, 'manual-locale.js'), 'utf8');
let browser;

before(async () => {
    browser = await chromium.launch({headless: true});
});
after(async () => {
    if (browser) await browser.close();
});

/** Supply the reader's native event boundary without an SGN application server. */
function readerHTML(locale) {
    const metadata = JSON.stringify({locale, language: 'Language', labels: {}});
    return `<!doctype html><html lang="${locale}"><head><meta charset="utf-8"></head><body>
<div class="book-header"></div><div class="book-summary"></div><main class="page-inner"></main>
<script type="application/json" id="manual-locale-ui">${metadata}</script>
<script>
const callbacks = {};
window.gitbook = {events: {
    bind(name, callback) { (callbacks[name] ||= []).push(callback); },
    emit(name) { for (const callback of callbacks[name] || []) callback(); }
}};
</script>
<script src="/manual-locale.js"></script></body></html>`;
}

for (const locale of ['en', 'uk']) {
    test(`${locale}: current section and chapter survive copy/open-in-new-tab navigation`, async () => {
        const context = await browser.newContext();
        const errors = [];
        context.on('page', page => page.on('pageerror', error => errors.push(error.message)));
        try {
            await context.route('**/*', route => {
                const url = new URL(route.request().url());
                assert.equal(url.origin, origin, 'the fixture must not request external resources');
                if (url.pathname === '/manual-locale.js') {
                    return route.fulfill({contentType: 'application/javascript', body: source});
                }
                const current = /^\/(uk|es|ar)\//.exec(url.pathname);
                return route.fulfill({contentType: 'text/html', body: readerHTML(current ? current[1] : 'en')});
            });
            const page = await context.newPage();
            const prefix = locale === 'en' ? '' : `${locale}/`;
            await page.goto(`${origin}/${prefix}managing-field-trials.html#first`);
            const link = page.locator('.manual-language-nav a[lang="ar"]');
            const initial = `${origin}/ar/managing-field-trials.html#first`;
            assert.equal(await link.getAttribute('href').then(value => new URL(value, page.url()).href), initial);

            await page.evaluate(() => { location.hash = '#later-section'; });
            const section = `${origin}/ar/managing-field-trials.html#later-section`;
            await page.waitForFunction(expected => document.querySelector('.manual-language-nav a[lang="ar"]').href === expected, section);
            assert.equal(await link.evaluate(element => element.href), section, 'copied link contains the current section');

            await page.evaluate(currentPrefix => {
                history.replaceState(null, '', `/${currentPrefix}managing-seedlots.html#seedlots`);
                gitbook.events.emit('page.change');
                gitbook.events.emit('page.change');
            }, prefix);
            const chapter = `${origin}/ar/managing-seedlots.html#seedlots`;
            await page.waitForFunction(expected => document.querySelector('.manual-language-nav a[lang="ar"]').href === expected, chapter);
            assert.equal(await page.locator('.manual-language-nav').count(), 1, 'repeated page events do not duplicate navigation');
            assert.equal(await link.getAttribute('href').then(value => new URL(value, page.url()).href), chapter, 'copy/open link uses the current chapter and section');

            const opened = context.waitForEvent('page');
            await link.click({modifiers: ['ControlOrMeta']});
            const tab = await opened;
            await tab.waitForURL(chapter);
            await tab.waitForLoadState('domcontentloaded');
            assert.equal(tab.url(), chapter, 'native open-in-new-tab navigation preserves the live href');
            assert.deepEqual(errors, []);
        } finally {
            await context.close();
        }
    });
}
