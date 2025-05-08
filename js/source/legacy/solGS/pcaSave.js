/*
 *Saves pca scores
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 * requires solGS.analysisSave
 */

jQuery(document).ready(function () {
  jQuery('body').on("click", ".download_pca_output", function (e) {
    var elemId = e.target.id;
    if(elemId.match(/save_pcs_btn/)) {
        var pcaArgs = solGS.pca.getPcaAnalysisArgs(elemId);

        var savePcaBtnId = `#${elemId}`;
        var pcaFileId = elemId.replace("save_pcs_btn_", '');
        var pcaSaveMsgDiv = `#${pcaFileId}_pca_save_message`;

        solGS.analysisSave.checkStoredAnalysis(pcaArgs).done(function (res) {
            if (res.analysis_id) {
                jQuery("#save_pcs_btn").hide();
                var link = '<a href="/analyses/' + res.analysis_id + '">View stored PCs</a>';
                jQuery(savePcaBtnId).html(link);
            } else {
                jQuery(pcaSaveMsgDiv)
                .html("Please wait...saving the PCs may take a few minutes.")
                .show();
                jQuery(`#${elemId}`).hide();

                solGS.analysisSave.checkUserStatus().done(function (res) {
                    if (!res.loggedin) {
                        solGS.submitJob.loginAlert();
                    } 
                }).fail(function () {
                    solGS.alertMessage("Error occured checking for user status");
                });

                solGS.analysisSave.getPcaResultDetails(pcaArgs).done(function (res) {
                    if (res.error) {
                        jQuery("#download_pca_output .multi-spinner-container").hide();
                        jQuery(pcaSaveMsgDiv)
                        .html(res.error + ". There may not be logged info for this analysis.")
                        .show()
                        .fadeOut(50000);
                        jQuery(`#${elemId}`).show();
                    } else {
                        solGS.analysisSave.storeAnalysisResults(res.analysis_details).done(function (res) {
                            jQuery("#download_pca_output .multi-spinner-container").hide();
                            if (res.error) {
                                jQuery(pcaSaveMsgDiv).html(res.error).show().fadeOut(50000);

                                jQuery(`#${elemId}`).show();
                            } else {
                                jQuery(pcaSaveMsgDiv).hide();

                                var link = '<a href="/analyses/' + res.analysis_id + '">View stored PC scores</a>';
                                jQuery(`#${elemId}`).html(link).show();
                            }
                        }).fail(function (res) {
                            jQuery(`#${elemId}`).show();
                            jQuery(pcaSaveMsgDiv).html(res.error).show().fadeOut(50000);
                        });
                    }
                });
            }});
        }
    });
});
