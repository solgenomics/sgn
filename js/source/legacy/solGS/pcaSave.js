/*
 *Saves solgs modeling output
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

// var solGS = solGS || function solGS() {};

solGS.pca.save = {
  checkStoredAnalysis: function (args) {
    args = JSON.stringify(args);
    var stored = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: {'arguments': args},
      url: "/solgs/check/stored/analysis/",
    });

    return stored;
  },

  getResultDetails: function (args) {
    var args = JSON.stringify(args);
    var details = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: {'arguments': args},
      url: "/solgs/analysis/result/details",
    });

    return details;
  },

  savePcaScores: function (args) {
    var save = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: args,
      url: "/ajax/analysis/store/json",
    });

    return save;
  },

  checkUserStatus: function () {
    return jQuery.ajax({
      type: "POST",
      dataType: "json",
      url: "/solgs/check/user/login/",
    });
  },
};

jQuery(document).ready(function () {
  jQuery('body').on("click", ".download_pca_output", function (e) {
    var elemId = e.target.id;
    if(elemId.match(/save_pcs_btn/)) {
        console.log(`saving pcs....elemId: ${elemId}`)
        var pcaArgs = solGS.pca.getSelectedPopPcaArgs(elemId);
        console.log(`saving pcs....elemId: ${elemId} -- pcaArgs: ${JSON.stringify(pcaArgs)}`)
        var pcaFileId = elemId.replace("save_pcs_btn_", '');
        console.log(`saving pcs....pcaFileId: ${pcaFileId}`)
        var pcaSaveMsgDiv = `#${pcaFileId}_pca_save_message`;

        solGS.pca.save.checkStoredAnalysis(pcaArgs).done(function (res) {
            console.log(`checkStoredAnalysis res: ${JSON.stringify(res)}`)
            if (res.analysis_id) {
                jQuery("#save_pcs_btn").hide();
                var link = '<a href="/analyses/' + res.analysis_id + '">View stored PCs</a>';
                jQuery("#download_").html(link);
            } else {
                jQuery(pcaSaveMsgDiv)
                .html("Please wait...saving the PCs may take a few minutes.")
                .show();
                jQuery(`#${elemId}`).hide();

                solGS.pca.save.checkUserStatus().done(function (res) {
                    console.log(`saving pcs....checkUserStatus loggedIn: ${res.loggedin}`)
                    if (!res.loggedin) {
                        solGS.submitJob.loginAlert();
                    } 
                }).fail(function () {
                    solGS.alertMessage("Error occured checking for user status");
                });

                solGS.pca.save.getResultDetails(pcaArgs).done(function (res) {
                    console.log(`getResultDetails: res.analysis_details -- ${JSON.stringify(res.analysis_details)} `)
                    if (res.error) {
                        jQuery("#download_pca_output .multi-spinner-container").hide();
                        jQuery(pcaSaveMsgDiv)
                        .html(res.error + ". There may not be logged info for this analysis.")
                        .show()
                        .fadeOut(50000);
                        jQuery(`#${elemId}`).show();
                    } else {
                        solGS.pca.save.savePcaScores(res.analysis_details).done(function (res) {
                            console.log(`savePcaScores: res -- ${JSON.stringify(res)} `)

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
