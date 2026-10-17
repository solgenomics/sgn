import test from 'tape';
import { findDataset, linkFor } from '../source/entries/jbrowse_datasets.js';

const conf = [
    '[GENERAL]',
    'dataRoot = data/json/genome',
    '',
    '[datasets.Accession_42048]',
    'url  = ?data=data/json/genome&loc=chr3:100..200&tracks=DNA,line_42048',
    'name = Line 42048',
    '',
    '[datasets.Accession_7]',
    'name = no url here',
    '',
    '[datasets.Accession_9]',
    'url = javascript:alert(1)',
    '',
    '[datasets.Trial_221]',
    'url = ?data=data/json/trials/221',
].join('\r\n');

const fallback = '/jbrowse/?data=data/json%2Faccessions%2F7';

test('JBrowse datasets', t => {
    t.deepEqual(findDataset(conf, 'Accession_42048'),
        { found: true, url: '?data=data/json/genome&loc=chr3:100..200&tracks=DNA,line_42048' },
        'finds the block and its url');
    t.equal(linkFor(conf, 'Accession_42048', '/jbrowse/', fallback),
        '/jbrowse/?data=data/json/genome&loc=chr3:100..200&tracks=DNA,line_42048',
        'links to the dataset\'s own url');
    ['Accession_4204', 'Accession_420', 'Accession_4'].forEach(prefix => {
        t.equal(linkFor(conf, prefix, '/jbrowse/', fallback), null,
            prefix + ' does not match Accession_42048');
    });
    t.equal(linkFor(conf, 'Accession_7', '/jbrowse/', fallback), fallback,
        'a block without url keeps the previous link');
    t.equal(linkFor(conf, 'Accession_9', '/jbrowse/', fallback), fallback,
        'an unsafe url is not linked');
    t.equal(linkFor(conf, 'Trial_221', '/jbrowse/', fallback), '/jbrowse/?data=data/json/trials/221',
        'trials work the same way');
    t.equal(linkFor('', 'Accession_42048', '/jbrowse/', fallback), null, 'empty configuration');
    t.equal(linkFor('# Accession_42048 only in a comment', 'Accession_42048', '/jbrowse/', fallback), null,
        'a mention outside a dataset header is not a dataset');
    t.end();
});
