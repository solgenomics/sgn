/**
 * Exact JBrowse 1 dataset lookup for accession and trial links. A dataset's
 * configured query selects its data directory, location and tracks; the native
 * link supplies defaults when the dataset has no URL or omits track selection.
 */
function findDataset(confText, id) {
    var lines = String(confText == null ? '' : confText).split(/\r?\n/);
    var header = 'datasets.' + id;
    var inside = false;
    var found = false;
    var url = null;
    for (var i = 0; i < lines.length; i++) {
        var match = /^\s*\[\s*([^\]]*?)\s*\]\s*(?:#.*)?$/.exec(lines[i]);
        if (/^\s*\[/.test(lines[i])) {
            inside = Boolean(match && match[1] === header);
            if (inside) found = true;
        } else if (inside && url === null) {
            var value = /^\s*url\s*=\s*(\S.*?)\s*$/.exec(lines[i]);
            if (value) url = value[1];
        }
    }
    return { found: found, url: url };
}

/**
 * Whether a jbrowse.conf has an exactly named dataset block.
 * @param {string} confText - the text of jbrowse.conf
 * @param {string} id - the dataset name, e.g. "Accession_42048"
 * @returns {boolean}
 */
export function hasDataset(confText, id) {
    return findDataset(confText, id).found;
}

/**
 * Link to an exact dataset using its configured query on this JBrowse page.
 * Only query URLs are accepted; other URL forms retain the native fallback.
 * Explicit dataset tracks/category/highlight values win, including empty values.
 * @param {string} confText - the text of jbrowse.conf
 * @param {string} id - the exact dataset name
 * @param {string} base - the JBrowse page path, e.g. "/jbrowse/"
 * @param {string} fallback - the native page's default link
 * @returns {?string} the link, or null if the dataset is absent
 */
export function linkFor(confText, id, base, fallback) {
    var dataset = findDataset(confText, id);
    if (!dataset.found) return null;
    if (!dataset.url || !/^\?[^\s<>"'`\\#]*$/.test(dataset.url)) return fallback;
    var query = dataset.url;
    var params = new URLSearchParams(query.substring(1));
    var fallbackQuery = fallback.substring(fallback.indexOf('?') + 1).split('&');
    ['tracks', 'cat', 'highlight'].forEach(function (name) {
        if (params.has(name)) return;
        for (var i = 0; i < fallbackQuery.length; i++) {
            if (fallbackQuery[i].indexOf(name + '=') === 0) {
                query += '&' + fallbackQuery[i];
                break;
            }
        }
    });
    return base + query;
}
