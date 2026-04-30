/*  used by dataset detail page */

var datasets = new CXGN.Dataset();

function datasetDelete(val) {
    if ( confirm(`Dataset. Are you sure you would like to delete it? Deletion cannot be undone.`)) {
        datasets.deleteDataset(val);
    }
}

function datasetPublic(val) {
    datasets.makePublicDataset(val, () => {
        jQuery("#dataset-edit-private").show();
        jQuery("#dataset-edit-public").hide();
    });
}

function datasetPrivate(val) {
    datasets.makePrivateDataset(val, () => {
        jQuery("#dataset-edit-private").hide();
        jQuery("#dataset-edit-public").show();
    });
}

function datasetEdit() {
    jQuery("#dataset-description-display").hide();
    jQuery("#dataset-description-update").show();
}

function datasetUpdate(val) {
    datasets.updateDescription(val, (updated) => {
        jQuery("#dataset-description-update-content").html(updated.replace(/\n/g, "<br />"))
        jQuery("#dataset-description-display").show();
        jQuery("#dataset-description-update").hide();
    });
}

