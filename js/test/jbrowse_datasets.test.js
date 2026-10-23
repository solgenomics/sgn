import test from 'tape';
import { hasDataset } from '../source/entries/jbrowse_datasets.js';

const conf = [
    '[GENERAL]',
    'dataRoot = data/json/genome',
    '',
    '[datasets.Accession_42048]',
    'url  = ?data=data/json/accessions/42048',
    'name = Line 42048',
    '',
    '[ datasets.Accession_7 ]  # spaces and a comment',
    'name = Line 7',
    '',
    '[datasets.Trial_221]',
    'url = ?data=data/json/trials/221',
].join('\r\n');

test('JBrowse datasets', t => {
    t.equal(hasDataset(conf, 'Accession_42048'), true, 'finds the dataset by its exact name');
    ['Accession_4204', 'Accession_420', 'Accession_4'].forEach(prefix => {
        t.equal(hasDataset(conf, prefix), false, prefix + ' does not match Accession_42048');
    });
    t.equal(hasDataset(conf, 'Accession_420480'), false, 'a longer id does not match either');
    t.equal(hasDataset(conf, 'Accession_7'), true, 'spaces inside the brackets and a comment are allowed');
    t.equal(hasDataset(conf, 'Trial_221'), true, 'trials work the same way');
    t.equal(hasDataset(conf, 'Trial_22'), false, 'a trial id prefix does not match');
    t.equal(hasDataset('', 'Accession_42048'), false, 'empty configuration');
    t.equal(hasDataset(null, 'Accession_42048'), false, 'no configuration');
    t.equal(hasDataset('# Accession_42048 only in a comment\nurl = ?data=data/json/accessions/42048', 'Accession_42048'), false,
        'a mention outside a dataset header is not a dataset');
    t.end();
});
