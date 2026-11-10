/**
 * SGN browser translator.
 *
 * Served as /i18n/runtime.js when i18n_enabled is set. /i18n/bootstrap.js then
 * creates SGN.i18n with the messages of the page language. Use the short
 * helpers SGN.t(context, english, variables) and
 * SGN.tn(context, one, many, count, variables); js/source/legacy/sgn.js gives
 * English versions of the same helpers when translation is off.
 *
 * Plural rules come with the messages as a small syntax tree ("pluralAst"), built
 * and checked by the translation tools. This file validates and evaluates that
 * tree exactly like lib/SGN/I18N.pm; it never parses or runs catalog text.
 */
(function (root) {
    'use strict';
    var own = function (object, key) { return Object.prototype.hasOwnProperty.call(object, key); };
    var maxInteger = 9007199254740991;
    var binaryTypes = {OR: 1, AND: 1, LT: 1, GT: 1, LTE: 1, GTE: 1, EQ: 1, NEQ: 1, MOD: 1};
    // Counts checked when a catalog is loaded, as in SGN::I18N.
    var sampleCounts = [];
    for (var sample = 0; sample <= 200; sample++) sampleCounts.push(sample);
    sampleCounts.push(999, 1000, 1001, 1000000, maxInteger);

    function validCount(count) {
        if (!Number.isSafeInteger(count) || count < 0) throw new Error('Plural count must be a nonnegative safe integer');
        return count;
    }

    // A constant is a non-negative safe integer, or a string of its decimal
    // digits; SGN::I18N accepts the same.
    function constant(value) {
        if (typeof value === 'string' && /^(?:0|[1-9][0-9]*)$/.test(value)) value = Number(value);
        return validCount(value);
    }

    // The %{name} placeholders used in a text.
    function placeholders(text) {
        var names = [];
        text.replace(/%\{([A-Za-z_][A-Za-z0-9_]*)\}/g, function (_, name) { names.push(name); });
        return names;
    }

    // Check the node types, fields and size of a plural syntax tree.
    function validateAst(ast) {
        var size = 0;
        function visit(node, depth) {
            if (!node || typeof node !== 'object' || Array.isArray(node) || ++size > 128 || depth > 24) {
                throw new Error('Invalid or oversized plural AST');
            }
            var keys;
            if (node.type === 'VAR') {
                keys = ['type'];
            } else if (node.type === 'NUM') {
                constant(node.val);
                keys = ['type', 'val'];
            } else if (node.type === 'GROUP') {
                keys = ['type', 'expr'];
                visit(node.expr, depth + 1);
            } else if (node.type === 'TERNARY') {
                keys = ['type', 'expr', 'truthy', 'falsey'];
                visit(node.expr, depth + 1);
                visit(node.truthy, depth + 1);
                visit(node.falsey, depth + 1);
            } else if (typeof node.type === 'string' && own(binaryTypes, node.type)) {
                keys = ['type', 'left', 'right'];
                visit(node.left, depth + 1);
                visit(node.right, depth + 1);
                if (node.type === 'MOD' && node.right.type === 'NUM' && node.right.val === 0) throw new Error('Plural division by zero');
            } else {
                throw new Error('Unsupported plural AST operator');
            }
            if (Object.keys(node).sort().join(',') !== keys.sort().join(',')) throw new Error('Unexpected plural AST field');
        }
        visit(ast, 0);
        return ast;
    }

    // Evaluate a validated tree for n. Like GNU gettext, comparisons and
    // logical operators give 0 or 1.
    function evaluate(node, n) {
        switch (node.type) {
        case 'VAR': return n;
        case 'NUM': return constant(node.val);
        case 'GROUP': return evaluate(node.expr, n);
        case 'TERNARY': return evaluate(evaluate(node.expr, n) ? node.truthy : node.falsey, n);
        case 'OR': return evaluate(node.left, n) || evaluate(node.right, n) ? 1 : 0;
        case 'AND': return evaluate(node.left, n) && evaluate(node.right, n) ? 1 : 0;
        }
        var left = evaluate(node.left, n);
        var right = evaluate(node.right, n);
        switch (node.type) {
        case 'LT': return left < right ? 1 : 0;
        case 'GT': return left > right ? 1 : 0;
        case 'LTE': return left <= right ? 1 : 0;
        case 'GTE': return left >= right ? 1 : 0;
        case 'EQ': return left === right ? 1 : 0;
        case 'NEQ': return left !== right ? 1 : 0;
        case 'MOD':
            if (!right) throw new Error('Plural division by zero');
            return left % right;
        }
        throw new Error('Unsupported plural AST operator');
    }

    function evaluatePlural(ast, count) {
        return evaluate(ast, validCount(count));
    }

    function format(text, variables) {
        variables = variables || {};
        if (typeof variables !== 'object' || Array.isArray(variables)) throw new Error('Named variables must be an object');
        return text.replace(/%\{([A-Za-z_][A-Za-z0-9_]*)\}/g, function (_, name) {
            if (!own(variables, name) || variables[name] == null || typeof variables[name] === 'object' || typeof variables[name] === 'function') {
                throw new Error('Missing or invalid named variable: ' + name);
            }
            return String(variables[name]);
        });
    }

    function languageName(value) {
        if (typeof value !== 'string' || !value.trim() || Array.from(value).length > 200 || /[\x00-\x1f\x7f-\x9f\u2028\u2029]/.test(value)) {
            throw new Error('Invalid native language name');
        }
        return value;
    }

    /**
     * Create an independent plain-text translator from validated catalog data.
     * @constructor
     * @param {Object} [payload] Locale, direction, domain and data-only catalogs.
     */
    function I18N(payload) {
        payload = payload || {locale: 'en', dir: 'ltr', domain: 'sgn', catalogs: []};
        if (typeof payload.locale !== 'string' || !/^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$/.test(payload.locale)) throw new Error('Invalid locale');
        if (payload.dir !== 'ltr' && payload.dir !== 'rtl') throw new Error('Invalid direction');
        if (typeof payload.domain !== 'string' || !/^[a-z][a-z0-9_-]*$/.test(payload.domain) || payload.domain === '__proto__') throw new Error('Invalid catalog domain');
        if (!Array.isArray(payload.catalogs)) throw new Error('Catalogs must be an array');
        var requestedLocale = payload.requestedLocale === undefined ? payload.locale : payload.requestedLocale;
        if (typeof requestedLocale !== 'string' || !/^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$/.test(requestedLocale) || /[\r\n]/.test(requestedLocale)) throw new Error('Invalid requested locale');
        this.requestedLocale = requestedLocale;
        this.locale = payload.locale;
        this.languageName = payload.languageName === undefined ? (this.locale === 'en' ? 'English' : this.locale) : languageName(payload.languageName);
        this.dir = payload.dir;
        this.domain = payload.domain;
        // A defective catalog or message is skipped with a warning, so the
        // page shows English for it and keeps the usable translations.
        var warn = function (text) { if (root.console) root.console.warn('SGN.I18N: ' + text); };
        this.catalogs = [];
        payload.catalogs.forEach(function (source) {
            try { this.catalogs.push(checkedCatalog(source, warn)); } catch (error) { warn('ignoring a catalog: ' + error.message); }
        }, this);
    }

    // Copy and check one catalog; drop its defective messages.
    function checkedCatalog(source, warn) {
        var catalog = JSON.parse(JSON.stringify(source));
        if (!catalog || catalog.schema !== 1 || catalog.api !== 1) throw new Error('Unsupported catalog schema');
        if (catalog.languageName !== undefined) languageName(catalog.languageName);
        if (!Number.isInteger(catalog.nplurals) || catalog.nplurals < 1 || catalog.nplurals > 6) throw new Error('Invalid plural form count');
        validateAst(catalog.pluralAst);
        sampleCounts.forEach(function (count) {
            var index = evaluatePlural(catalog.pluralAst, count);
            if (index < 0 || index >= catalog.nplurals) throw new Error('Plural index outside catalog forms');
        });
        if (!catalog.messages || typeof catalog.messages !== 'object' || Array.isArray(catalog.messages)) throw new Error('Invalid catalog messages');
        Object.keys(catalog.messages).forEach(function (key) {
            var message = catalog.messages[key];
            var english = key.slice(key.indexOf('\u0004') + 1);
            var defect = !message || !Array.isArray(message.forms) || (message.plural !== null && typeof message.plural !== 'string') ? 'invalid message'
                : message.forms.length !== (message.plural === null ? 1 : catalog.nplurals) ? 'incomplete plural forms'
                : message.forms.some(function (form) { return typeof form !== 'string' || !form.length; }) ? 'invalid form' : null;
            if (defect) {
                delete catalog.messages[key];
                warn('ignoring the ' + catalog.locale + ' translation of "' + english + '": ' + defect);
                return;
            }
            // A translation may only use the placeholders of its English
            // text. Otherwise drop it, so the page shows English.
            var allowed = placeholders(english).concat(message.plural === null ? [] : placeholders(message.plural));
            var unknown = message.forms.map(placeholders).reduce(function (all, names) { return all.concat(names); }, [])
                .filter(function (name) { return allowed.indexOf(name) < 0; });
            if (unknown.length) {
                delete catalog.messages[key];
                warn('ignoring the ' + catalog.locale + ' translation of "' + english + '": unknown placeholder %{' + unknown[0] + '}');
            }
        });
        return {data: catalog};
    }

    // Use the translation unless it fails; a translation never breaks the caller.
    // Each failing message is reported once per page, as SGN::I18N does per process.
    var reported = {};
    function render(translate, english, variables) {
        var fallback = format(english, variables);    // caller errors still throw
        try {
            return translate();
        } catch (error) {
            var key = english + '\u0004' + error.message;
            if (!own(reported, key) && root.console) root.console.warn('SGN.I18N: using English for "' + english + '": ' + error.message);
            reported[key] = true;
            return fallback;
        }
    }

    /**
     * Translate one complete message and substitute named values once.
     * @param {string} context Semantic message context.
     * @param {string} text Exact English fallback text.
     * @param {Object} [variables] Literal values for named placeholders.
     * @returns {string} Plain text; callers escape for the destination sink.
     */
    I18N.prototype.p = function (context, text, variables) {
        if (typeof context !== 'string' || typeof text !== 'string') throw new Error('Translation context and text must be strings');
        var key = context + '\u0004' + text;
        for (var i = 0; i < this.catalogs.length; i++) {
            var entry = this.catalogs[i];
            if (own(entry.data.messages, key) && entry.data.messages[key].plural === null) {
                var translated = entry.data.messages[key].forms[0];
                return render(function () { return format(translated, variables); }, text, variables);
            }
        }
        return format(text, variables);
    };

    /**
     * Select a validated language plural form without changing numeric data.
     * @param {string} context Semantic message context.
     * @param {string} one English singular fallback.
     * @param {string} many English plural fallback.
     * @param {number} count Nonnegative safe integer selecting the form.
     * @param {Object} [variables] Literal values for named placeholders.
     * @returns {string} Plain text; callers escape for the destination sink.
     */
    I18N.prototype.np = function (context, one, many, count, variables) {
        validCount(count);
        if (typeof context !== 'string' || typeof one !== 'string' || typeof many !== 'string') throw new Error('Translation context and texts must be strings');
        var key = context + '\u0004' + one;
        var english = count === 1 ? one : many;
        for (var i = 0; i < this.catalogs.length; i++) {
            var entry = this.catalogs[i];
            if (own(entry.data.messages, key) && entry.data.messages[key].plural === many) {
                return render(pluralForm(entry.data, entry.data.messages[key], count, variables), english, variables);
            }
        }
        return format(english, variables);
    };

    function pluralForm(catalog, message, count, variables) {
        return function () {
            var index = evaluatePlural(catalog.pluralAst, count);
            if (index < 0 || index >= message.forms.length) throw new Error('Plural index outside catalog forms');
            return format(message.forms[index], variables);
        };
    }

    /**
     * Validate a plural syntax tree and evaluate it for one count.
     * @param {Object} ast Plural syntax tree.
     * @param {number} count Non-negative safe integer.
     * @returns {number} Index of the plural form.
     */
    I18N.evaluatePlural = function (ast, count) { return evaluatePlural(validateAst(ast), count); };
    /**
     * Send the page language with same-site jQuery AJAX requests, so their
     * responses use the language of the page. The server reads the
     * X-SGN-Locale header. Called by the page header only when translation
     * is on; requests to other sites get no extra header.
     * @param {Function} jQuery The page's jQuery.
     * @param {Object} target Usually window; its SGN.i18n gives the language.
     */
    I18N.sendLocaleWithAjax = function (jQuery, target) {
        jQuery.ajaxPrefilter(function (options, originalOptions, request) {
            var page = target.SGN && target.SGN.i18n;
            if (page && !options.crossDomain) request.setRequestHeader('X-SGN-Locale', page.locale);
        });
    };
    /**
     * Define SGN.t and SGN.tn on a global object. They always use the current
     * SGN.i18n, so a later bootstrap can replace the catalog.
     * @param {Object} target Usually window.
     */
    I18N.install = function (target) {
        target.SGN = target.SGN || {};
        var english = new I18N();
        /** Translate plain text using the current page catalog, or English. */
        target.SGN.t = function (context, text, variables) {
            return (target.SGN.i18n || english).p(context, text, variables);
        };
        /** Translate a counted message without changing its numeric value. */
        target.SGN.tn = function (context, one, many, count, variables) {
            return (target.SGN.i18n || english).np(context, one, many, count, variables);
        };
    };
    if (typeof module !== 'undefined' && module.exports) module.exports = I18N;
    else {
        root.SGN = root.SGN || {};
        root.SGN.I18N = I18N;
        root.SGN.i18n = new I18N();
        I18N.install(root);
    }
})(typeof globalThis !== 'undefined' ? globalThis : this);
