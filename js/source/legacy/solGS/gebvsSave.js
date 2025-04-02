jQuery(document).ready(function () {
    var analysisArgs = solGS.analysisSave.saveGebvsArgs();
      solGS.analysisSave.checkStoredAnalysis(analysisArgs).done(function (res) {
      if (res.analysis_id) {
        jQuery("#save_gebvs").hide();
        var link = '<a href="/analyses/' + res.analysis_id + '">View stored GEBVs</a>';
        jQuery("#gebvs_output").append(link);
        }
    });
  
    jQuery("#save_gebvs").click(function () {
      jQuery("#gebvs_output .multi-spinner-container").show();
      jQuery("#gebvs_save_message")
        .html("Please wait...saving the GEBVs may take a few minutes.")
        .show();
      jQuery("#save_gebvs").hide();
  
      solGS.analysisSave.checkUserStatus().done(function (res) {
        if (!res.loggedin) {
          solGS.submitJob.loginAlert();
        } else {
        }
      });
  
      solGS.analysisSave.checkUserStatus().fail(function () {
        solGS.alertMessage("Error occured checking for user status");
      });
  
      solGS.analysisSave.getGebvsResultDetails(analysisArgs).done(function (res) {
  
        if (res.error) {
          jQuery("#gebvs_output .multi-spinner-container").hide();
          jQuery("#gebvs_save_message")
            .html(res.error + ". The logged info may not exist for the result.")
            .show()
            .fadeOut(50000);
  
          jQuery("#save_gebvs").show();
        } else {
          var save = solGS.analysisSave.storeAnalysisResults(res.analysis_details);
  
          save.done(function (res) {
            jQuery("#gebvs_output .multi-spinner-container").hide();
            if (res.error) {
              jQuery("#gebvs_save_message").html(res.error).show().fadeOut(50000);
  
              jQuery("#save_gebvs").show();
            } else {
              jQuery("#gebvs_save_message").hide();
  
              var link = '<a href="/analyses/' + res.analysis_id + '">View stored GEBVs</a>';
              jQuery("#gebvs_output").append(link);
            }
          });
  
          save.fail(function (res) {
            jQuery("#gebvs_output .multi-spinner-container").hide();
            jQuery("#save_gebvs").show();
            jQuery("#gebvs_save_message").html(res.error).show().fadeOut(50000);
          });
        }
      });
    });
  });
  