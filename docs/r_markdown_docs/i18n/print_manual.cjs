#!/usr/bin/env node
/**
 * @file Export a translated Bookdown reader to PDF using local resources only.
 * @example node print_manual.cjs /absolute/full-book-html /absolute/manual.pdf uk
 * Requires the isolated package dependencies and their Chromium installation.
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {chromium} = require('playwright');
const [directory, destination, locale] = process.argv.slice(2);
assert(directory && destination && ['uk', 'es', 'ar'].includes(locale),
    'Usage: node print_manual.cjs HTML_DIRECTORY OUTPUT.pdf uk|es|ar');
const root = fs.realpathSync(directory);
const output = path.resolve(destination);
assert(output.endsWith('.pdf'), 'Output must be a PDF');
assert(fs.existsSync(path.join(root, 'BreedbaseManual.html')), 'Build single-page HTML first');
const figures = [1, 2, 3, 4].map(number => ({
    html: `assets/gifs/gif${number}.gif`, pdf: `assets/gifs/gif${number}.png`
}));
for (const figure of figures) {
    const target = path.join(root, figure.pdf);
    if (!fs.existsSync(target)) {
        const original = path.resolve(__dirname, '..', figure.pdf);
        assert(fs.existsSync(original), 'Original static figure is missing: ' + figure.pdf);
        fs.mkdirSync(path.dirname(target), {recursive:true});
        fs.copyFileSync(original, target);
    }
}
const fuse = fs.readFileSync(require.resolve('fuse.js/dist/fuse.min.js'));
const origin = 'https://manual-print.invalid';
const types = {'.html':'text/html', '.css':'text/css', '.js':'application/javascript',
    '.json':'application/json', '.png':'image/png', '.gif':'image/gif', '.jpg':'image/jpeg',
    '.jpeg':'image/jpeg', '.ttf':'font/ttf', '.woff':'font/woff', '.woff2':'font/woff2', '.svg':'image/svg+xml'};
(async () => {
    const browser = await chromium.launch({headless:true, args:['--renderer-process-limit=1', '--disable-gpu']});
    const errors = [], missing = [], blocked = [];
    try {
        const context = await browser.newContext({viewport:{width:1100, height:1000}});
        await context.route('**/*', route => {
            const url = new URL(route.request().url());
            if (url.href === 'https://cdn.jsdelivr.net/npm/fuse.js@6.4.6/dist/fuse.min.js') {
                return route.fulfill({contentType:'application/javascript', body:fuse});
            }
            if (url.origin !== origin) { blocked.push(url.href); return route.abort(); }
            const relative = url.pathname === '/' ? '/BreedbaseManual.html' : decodeURIComponent(url.pathname);
            const file = path.resolve(root, '.' + relative);
            if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
                missing.push(relative); return route.fulfill({status:404, body:'Not found'});
            }
            const real = fs.realpathSync(file);
            assert(real.startsWith(root + path.sep), 'Resource symlink leaves the HTML directory');
            return route.fulfill({contentType:types[path.extname(file)] || 'application/octet-stream', body:fs.readFileSync(file)});
        });
        const page = await context.newPage();
        page.on('pageerror', error => errors.push(error.message));
        await page.goto(origin + '/', {waitUntil:'networkidle', timeout:120000});
        assert.equal(await page.locator('html').getAttribute('lang'), locale);
        assert.equal(await page.locator('html').getAttribute('dir'), locale === 'ar' ? 'rtl' : 'ltr');
        const replaced = await page.evaluate(items => {
            let count = 0;
            document.querySelectorAll('img').forEach(image => {
                const item = items.find(value => new URL(image.src).pathname.endsWith('/' + value.html));
                if (item) { image.src = new URL(item.pdf, location.href).href; count++; }
            });
            return count;
        }, figures);
        assert.equal(replaced, 4, 'Use the four original static print alternatives');
        await page.evaluate(async () => {
            await document.fonts.ready;
            await Promise.all([...document.images].map(image => image.decode().catch(() => {})));
        });
        await page.emulateMedia({media:'print'});
        await page.evaluate(() => {
            const walker = document.createTreeWalker(document.querySelector('section.normal'), NodeFilter.SHOW_TEXT);
            let node;
            while ((node = walker.nextNode())) {
                if (!node.parentElement.closest('pre,code,math,script,style')) {
                    node.nodeValue = node.nodeValue.replace(/(^|\s)[\u2010-\u2014](?=\s|$)/g, '$1-');
                }
            }
            document.querySelectorAll('a[href="/tools/mixedmodels"],a[href="/tools/gcpc"]').forEach(link => {
                const value = link.getAttribute('href'); link.removeAttribute('href');
                const code = document.createElement('code'); code.textContent = ' (' + value + ')'; link.appendChild(code);
            });
        });
        const broken = await page.locator('img').evaluateAll(images => images.filter(image => !image.complete || !image.naturalWidth).map(image => image.src));
        assert.deepEqual(broken, []); assert.deepEqual(errors, []); assert.deepEqual(missing, []);
        fs.mkdirSync(path.dirname(output), {recursive:true});
        await page.pdf({path:output, format:'A4', preferCSSPageSize:true, printBackground:true,
            tagged:true, outline:true, displayHeaderFooter:true, headerTemplate:'<span></span>',
            footerTemplate:'<div style="font:8px sans-serif;width:100%;text-align:center;direction:ltr"><span class="pageNumber"></span> / <span class="totalPages"></span></div>',
            margin:{top:'18mm', bottom:'18mm', left:'18mm', right:'18mm'}, timeout:180000});
        assert.equal(fs.readFileSync(output).subarray(0, 5).toString(), '%PDF-');
        console.log(JSON.stringify({locale, output, staticPrintFigures:replaced, brokenFigures:0,
            browserErrors:0, missingResources:0, blockedExternalRequests:blocked.length}));
    } finally { await browser.close(); }
})().catch(error => { console.error(error.stack); process.exitCode = 1; });
