jQuery(document).ready(function () {
  var analysisArgs = solGS.analysisSave.saveGebvsArgs();
  jQuery('#analysis_result_save_type').val('gebvs');
  analysisArgs['analysis_result_save_type'] = 'gebvs';
  solGS.analysisSave.checkStoredAnalysis(analysisArgs).done(function (res) {
    if (res.analysis_id) {
      jQuery("#save_gebvs").hide();
      var link = ' | <a href="/analyses/' + res.analysis_id + '">' + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.view_stored_gebvs", "View stored GEBVs") : "View stored GEBVs") + '</a> |';
      jQuery("#gebvs_output").append(link);
    }
  });
  
  jQuery("#save_gebvs").click(function () {
      
    console.log(`analysisArgs: ${JSON.stringify(analysisArgs)}`)
    jQuery("#gebvs_output .multi-spinner-container").show();
    jQuery("#gebvs_save_message")
      .html((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.saving_gebvs_wait", "Please wait...saving the GEBVs may take a few minutes.") : "Please wait...saving the GEBVs may take a few minutes."))
      .show();
    jQuery("#save_gebvs").hide();

    solGS.analysisSave.checkUserStatus().done(function (res) {
      if (!res.loggedin) {
        solGS.submitJob.loginAlert();
      } else {
      }
    });
  
    solGS.analysisSave.checkUserStatus().fail(function () {
      solGS.alertMessage((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.save_user_status_error", "Error occured checking for user status") : "Error occured checking for user status"));
    });
  
      solGS.analysisSave.getGebvsResultDetails(analysisArgs).done(function (res) {
  
        if (res.error) {
          jQuery("#gebvs_output .multi-spinner-container").hide();
          jQuery("#gebvs_save_message")
            .html(res.error + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.save_result_log_info_missing", ". The logged info may not exist for the result.") : ". The logged info may not exist for the result."))
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
  
              var link = ' | <a href="/analyses/' + res.analysis_id + '">' + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.view_stored_gebvs", "View stored GEBVs") : "View stored GEBVs") + '</a> |';
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


  jQuery(document).ready(function () {
    var analysisArgs = solGS.analysisSave.saveGebvsArgs();
    analysisArgs['analysis_result_save_type'] = 'genetic_values';
    jQuery('#analysis_result_save_type').val('genetic_values');
      solGS.analysisSave.checkStoredAnalysis(analysisArgs).done(function (res) {
      if (res.analysis_id) {
        jQuery("#save_genetic_values").hide();
        var link = ' | <a href="/analyses/' + res.analysis_id + '">' + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.view_stored_genetic_values", "View stored genetic values") : "View stored genetic values") + '</a> |';
        jQuery("#gebvs_output").append(link);
        }
    });
  
    jQuery("#save_genetic_values").click(function () {
      

      jQuery("#gebvs_output .multi-spinner-container").show();
      jQuery("#gebvs_save_message")
        .html((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.saving_genetic_values_wait", "Please wait...saving the genetic values (adjusted means) may take a few minutes.") : "Please wait...saving the genetic values (adjusted means) may take a few minutes."))
        .show();
      jQuery("#save_genetic_values").hide();
  
      solGS.analysisSave.checkUserStatus().done(function (res) {
        if (!res.loggedin) {
          solGS.submitJob.loginAlert();
        } else {
        }
      });
  
      solGS.analysisSave.checkUserStatus().fail(function () {
        solGS.alertMessage((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.save_user_status_error", "Error occured checking for user status") : "Error occured checking for user status"));
      });
  
      solGS.analysisSave.getGebvsResultDetails(analysisArgs).done(function (res) {
  
        if (res.error) {
          jQuery("#gebvs_output .multi-spinner-container").hide();
          jQuery("#gebvs_save_message")
            .html(res.error + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.save_result_log_info_missing", ". The logged info may not exist for the result.") : ". The logged info may not exist for the result."))
            .show()
            .fadeOut(50000);
  
          jQuery("#save_genetic_values").show();
        } else {
          var save = solGS.analysisSave.storeAnalysisResults(res.analysis_details);
  
          save.done(function (res) {
            jQuery("#gebvs_output .multi-spinner-container").hide();
            if (res.error) {
              jQuery("#gebvs_save_message").html(res.error).show().fadeOut(50000);
  
              jQuery("#save_genetic_values").show();
            } else {
              jQuery("#gebvs_save_message").hide();
  
              var link = '| <a href="/analyses/' + res.analysis_id + '">' + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.view_stored_genetic_values", "View stored genetic values") : "View stored genetic values") + '</a> |';
              jQuery("#gebvs_output").append(link);
            }
          });
  
          save.fail(function (res) {
            jQuery("#gebvs_output .multi-spinner-container").hide();
            jQuery("#save_genetic_values").show();
            jQuery("#gebvs_save_message").html(res.error).show().fadeOut(50000);
          });
        }
      });
    });
  });
  
  