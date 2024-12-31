/*  used by dataset detail page */

var datasets = new CXGN.Dataset();

function datasetDelete(val) {
    if ( confirm(`Dataset. Are you sure you would like to delete it? Deletion cannot be undone.`)) {
        datasets.deleteDataset(val);
    }
}

function datasetPublic(val) {
    datasets.makePublicDataset(val);
}

function datasetPrivate(val) {
    datasets.makePrivateDataset(val);
}

function datasetUpdate(val) {
    datasets.updateDescription(val);
}

