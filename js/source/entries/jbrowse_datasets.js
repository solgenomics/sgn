/**
 * Exact lookup of a JBrowse 1 dataset in a jbrowse.conf, for the accession
 * and trial pages.
 *
 * Those pages used to test `response.indexOf("Accession_<id>")`, so a stock
 * whose id is a prefix of another stock's id (4204 and 42048) found the other
 * stock's dataset, and the link always pointed to a fixed folder layout.
 * Here the `[datasets.<name>]` block is matched by its exact name, and the
 * link uses that block's own `url` value when it has one.
 */

/**
 * Find the `[datasets.<id>]` block of a jbrowse.conf.
 * @param {string} confText - the text of jbrowse.conf
 * @param {string} id - the dataset name, e.g. "Accession_42048"
 * @returns {{found: boolean, url: ?string}} whether the block exists, and its
 *   `url` value (null when the block has none)
 */
export function findDataset(confText, id) {
    var lines = String(confText == null ? '' : confText).split(/\r?\n/);
    var header = '[datasets.' + id + ']';
    var inside = false;
    var found = false;
    var url = null;
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.charAt(0) === '[') {
            inside = line === header;
            if (inside) found = true;
            continue;
        }
        if (inside && url === null) {
            var match = /^url\s*=\s*(.+)$/.exec(line);
            if (match) url = match[1].trim();
        }
    }
    return { found: found, url: url };
}

/**
 * The link for a dataset: the block's own `url` (a query on the JBrowse page,
 * `?data=...`) appended to `base`, the given fallback when the block has no
 * usable url, or null when there is no such dataset.
 * @param {string} confText - the text of jbrowse.conf
 * @param {string} id - the dataset name
 * @param {string} base - the JBrowse page path, e.g. "/jbrowse/"
 * @param {string} fallback - the link used when the block has no url
 * @returns {?string}
 */
export function linkFor(confText, id, base, fallback) {
    var dataset = findDataset(confText, id);
    if (!dataset.found) return null;
    if (dataset.url && /^\?[^\s<>"'`\\]*$/.test(dataset.url)) return base + dataset.url;
    return fallback;
}
