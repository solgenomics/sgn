/**
 * SeedQuest i18n — DOM translation engine (hardened rewrite, 2026-05-22)
 * =====================================================================
 * Translates the BreedBase UI from English (source) into other languages
 * by walking the DOM, plus explicit data-i18n keys for custom widgets.
 *
 * Dictionary is EXTERNAL: define window.SQ_I18N_DICTS = { uk: {...}, ru: {...} }
 * (each map is { "English phrase": "translation" }) and load it BEFORE this file.
 *
 * What this fixes vs the previous version:
 *   - data-i18n no longer wipes child elements (icons/markup survive)
 *   - exact, collision-free restore to English via stored originals (not a reverse map)
 *   - safe replacement (no String.replace "$" pattern bug)
 *   - idempotent: each text node translated once; observer won't re-touch it
 *   - data-safety: skips inputs/textarea/code; honours data-no-i18n on any subtree
 *   - sets <html lang>; multi-language ready
 *   - observer guarded so our own writes don't re-trigger it
 *
 * Data safety: never modifies <textarea> or text <input> values — only display
 * text, button/submit labels, and placeholder/title/aria-label. User-entered
 * data is sent to the server untouched.
 */
(function () {
    'use strict';

    /* ───────── Cookie helpers ───────── */
    function getCookie(name) {
        var m = document.cookie.match('(^|;)\\s*' + name + '\\s*=\\s*([^;]+)');
        return m ? m.pop() : null;
    }
    function setCookie(name, value, days) {
        var d = new Date();
        d.setTime(d.getTime() + (days || 365) * 864e5);
        document.cookie = name + '=' + value + ';path=/;expires=' + d.toUTCString() + ';SameSite=Lax';
    }

    /* ───────── Config ───────── */
    var COOKIE = 'sq_lang';
    var DEFAULT_LANG = 'en';                 // source language
    var DICTS = window.SQ_I18N_DICTS || {};  // { uk: {...}, ru: {...}, ... }

    var SKIP_TAGS = {
        SCRIPT: 1, STYLE: 1, CODE: 1, PRE: 1, TEXTAREA: 1, INPUT: 1,
        NOSCRIPT: 1, SVG: 1, CANVAS: 1, IFRAME: 1, MATH: 1, KBD: 1, SAMP: 1
    };
    var MIN_LEN = 2;            // ignore very short text nodes
    var SUBSTR_MIN_NODE = 16;   // only do substring matching on longer nodes
    var SUBSTR_MIN_KEY = 10;    // only substring-match reasonably long keys

    /* ───────── State ───────── */
    var _lang = DEFAULT_LANG;
    var _dict = null;                 // active { en: translated }
    var _keysSorted = [];             // dict keys, longest first (greedy)
    var _orig = new WeakMap();        // textNode -> original English (exact restore)
    var _observer = null;
    var _busy = false;                // guard: ignore mutations during our own writes

    function loadDict(lang) {
        _dict = DICTS[lang] || null;
        _keysSorted = _dict
            ? Object.keys(_dict).sort(function (a, b) { return b.length - a.length; })
            : [];
    }

    /* Should this element (and subtree) be skipped entirely? */
    function isSkipped(el) {
        if (!el) return true;
        if (SKIP_TAGS[el.tagName]) return true;
        if (el.nodeType === 1 && el.hasAttribute && el.hasAttribute('data-no-i18n')) return true;
        if (el.isContentEditable) return true;   // never touch editable regions
        return false;
    }
    function ancestorSkipped(node) {
        var el = node.parentElement;
        while (el) {
            if (isSkipped(el)) return true;
            el = el.parentElement;
        }
        return false;
    }

    /* Replace the meaningful text of a node, preserving surrounding whitespace,
       without String.replace pattern interpretation. */
    function setTrimmedText(node, trimmed, replacement) {
        var raw = node.nodeValue;
        var start = raw.indexOf(trimmed);
        if (start < 0) { node.nodeValue = replacement; return; }
        node.nodeValue = raw.slice(0, start) + replacement + raw.slice(start + trimmed.length);
    }

    /* ───────── Translate one text node (idempotent) ───────── */
    function translateTextNode(node) {
        if (!_dict || !node.nodeValue) return;
        if (_orig.has(node)) return;                 // already handled
        var txt = node.nodeValue.trim();
        if (txt.length < MIN_LEN) return;

        // Exact match — the common case (labels, headings, buttons)
        if (Object.prototype.hasOwnProperty.call(_dict, txt)) {
            _orig.set(node, node.nodeValue);
            setTrimmedText(node, txt, _dict[txt]);
            return;
        }

        // Substring match for longer instructional text
        if (txt.length >= SUBSTR_MIN_NODE) {
            var val = node.nodeValue, changed = false;
            for (var i = 0; i < _keysSorted.length; i++) {
                var key = _keysSorted[i];
                if (key.length < SUBSTR_MIN_KEY) break;   // sorted longest-first
                if (val.indexOf(key) !== -1) {
                    val = val.split(key).join(_dict[key]);
                    changed = true;
                }
            }
            if (changed) {
                _orig.set(node, node.nodeValue);
                node.nodeValue = val;
            }
        }
    }

    /* ───────── Translate display attributes (cosmetic only) ───────── */
    var ATTRS = ['placeholder', 'title', 'aria-label'];
    function translateAttributes(el) {
        if (!_dict || el.nodeType !== 1) return;
        for (var i = 0; i < ATTRS.length; i++) {
            var v = el.getAttribute(ATTRS[i]);
            if (v && _dict[v.trim()]) el.setAttribute(ATTRS[i], _dict[v.trim()]);
        }
        // Only button/submit value labels — never text input values (data safety)
        if (el.tagName === 'INPUT' && (el.type === 'button' || el.type === 'submit')) {
            var bv = (el.value || '').trim();
            if (_dict[bv]) el.value = _dict[bv];
        }
    }

    /* ───────── data-i18n keyed elements (preserve child markup) ───────── */
    function applyKeyed(el) {
        var key = el.getAttribute('data-i18n');
        if (!key) return;
        // Translate only the element's own text nodes, leaving child elements (icons) intact.
        var translated = (_lang !== DEFAULT_LANG && _dict && _dict[key]) ? _dict[key] : key;
        var textNode = null, n;
        for (n = el.firstChild; n; n = n.nextSibling) {
            if (n.nodeType === 3 && n.nodeValue.trim().length) { textNode = n; break; }
        }
        if (textNode) {
            if (!_orig.has(textNode)) _orig.set(textNode, textNode.nodeValue);
            setTrimmedText(textNode, textNode.nodeValue.trim(), translated);
        } else if (el.childElementCount === 0) {
            el.textContent = translated;   // safe: no child elements to lose
        }
    }

    /* ───────── Walk a subtree ───────── */
    function translateRoot(root) {
        if (!_dict || _lang === DEFAULT_LANG) return;
        _busy = true;
        try {
            var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
                acceptNode: function (node) {
                    return ancestorSkipped(node)
                        ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
                }
            });
            var node;
            while ((node = walker.nextNode())) translateTextNode(node);

            var els = root.querySelectorAll ? root.querySelectorAll('*') : [];
            for (var i = 0; i < els.length; i++) {
                if (isSkipped(els[i])) continue;
                translateAttributes(els[i]);
            }
            var keyed = root.querySelectorAll ? root.querySelectorAll('[data-i18n]') : [];
            for (var k = 0; k < keyed.length; k++) applyKeyed(keyed[k]);
        } finally { _busy = false; }
    }

    /* ───────── Restore subtree to English (exact, via stored originals) ───────── */
    function restoreRoot(root) {
        _busy = true;
        try {
            var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
            var node;
            while ((node = walker.nextNode())) {
                if (_orig.has(node)) { node.nodeValue = _orig.get(node); _orig['delete'](node); }
            }
            // Re-apply data-i18n keys as English source
            var keyed = root.querySelectorAll ? root.querySelectorAll('[data-i18n]') : [];
            for (var k = 0; k < keyed.length; k++) {
                var el = keyed[k], key = el.getAttribute('data-i18n');
                if (el.childElementCount === 0 && key) el.textContent = key;
            }
        } finally { _busy = false; }
        // Note: attribute restore intentionally minimal — page reload gives a clean EN.
    }

    /* ───────── Observer for AJAX/modal content ───────── */
    function startObserver() {
        if (_observer || _lang === DEFAULT_LANG) return;
        _observer = new MutationObserver(function (muts) {
            if (_busy) return;
            for (var i = 0; i < muts.length; i++) {
                var added = muts[i].addedNodes;
                for (var j = 0; j < added.length; j++) {
                    var node = added[j];
                    if (node.nodeType === 1) {
                        if (!ancestorSkipped(node)) translateRoot(node);
                    } else if (node.nodeType === 3 && !ancestorSkipped(node)) {
                        _busy = true; translateTextNode(node); _busy = false;
                    }
                }
            }
        });
        _observer.observe(document.body, { childList: true, subtree: true });
    }
    function stopObserver() {
        if (_observer) { _observer.disconnect(); _observer = null; }
    }

    /* ───────── Public API ───────── */
    function setLang(lang) {
        if (!DICTS[lang] && lang !== DEFAULT_LANG) lang = DEFAULT_LANG;
        if (lang === _lang) return;
        if (lang === DEFAULT_LANG) {
            stopObserver();
            restoreRoot(document.body);
            _lang = DEFAULT_LANG;
        } else {
            _lang = lang;
            loadDict(lang);
            translateRoot(document.body);
            startObserver();
        }
        document.documentElement.setAttribute('lang', _lang);
        setCookie(COOKIE, _lang, 365);
        updateButton();
    }
    function updateButton() {
        var btn = document.getElementById('sq-lang-btn');
        if (btn) btn.textContent = (_lang === 'en') ? '🇺🇦 UA' : '🇬🇧 EN';
    }
    // Back-compat: existing pages call sqToggleLang()
    window.sqToggleLang = function () { setLang(_lang === DEFAULT_LANG ? 'uk' : DEFAULT_LANG); };
    window.sqSetLang = setLang;

    /* ───────── Init ───────── */
    document.addEventListener('DOMContentLoaded', function () {
        _lang = getCookie(COOKIE) || DEFAULT_LANG;
        document.documentElement.setAttribute('lang', _lang);
        if (_lang !== DEFAULT_LANG && DICTS[_lang]) {
            loadDict(_lang);
            translateRoot(document.body);
            startObserver();
        } else {
            _lang = DEFAULT_LANG;
        }
        updateButton();
    });
})();
