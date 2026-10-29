/**
 * Exact lookup of a JBrowse 1 dataset in a jbrowse.conf, for the accession
 * and trial pages.
 *
 * Those pages used to test `response.indexOf("Accession_<id>")`, so a stock
 * whose id is a prefix of another stock's id (4204 and 42048) found the other
 * stock's dataset. Here the `[datasets.<name>]` header is matched by its exact
 * name.
 */

/**
 * Whether a jbrowse.conf has a `[datasets.<id>]` block.
 * @param {string} confText - the text of jbrowse.conf
 * @param {string} id - the dataset name, e.g. "Accession_42048"
 * @returns {boolean}
 */
export function hasDataset(confText, id) {
    var lines = String(confText == null ? '' : confText).split(/\r?\n/);
    var header = 'datasets.' + id;
    for (var i = 0; i < lines.length; i++) {
        // a section header, with optional spaces inside the brackets and an
        // optional comment after them
        var match = /^\s*\[\s*([^\]]*?)\s*\]\s*(?:#.*)?$/.exec(lines[i]);
        if (match && match[1] === header) return true;
    }
    return false;
}
