/*
 *Saves solgs modeling output
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.save = {
  checkStoredAnalysis: function () {
    var args = this.saveGebvsArgs();
    var checkArgs = JSON.stringify(args);
    var stored = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: {'arguments': checkArgs},
      url: "/solgs/check/stored/analysis/",
    });

    return stored;
  },

  getResultDetails: function () {
    var args = this.saveGebvsArgs();
    var resultArgs = JSON.stringify(args);
    var details = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: {'arguments': resultArgs},
      url: "/solgs/analysis/result/details",
    });

    return details;
  },

  saveGebvs: function (args) {
    var save = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: args,
      url: "/ajax/analysis/store/json",
    });

    return save;
  },

  saveGebvsArgs: function () {
    
    var analysisArgs = solGS.getSelectionPopArgs();
    analysisArgs['analysis_result_type'] = this.analysisResultType();
    analysisArgs['analysis_page'] = location.pathname;
  
    return analysisArgs;
  },

  analysisResultType: function () {
    return jQuery('#analysis_type').val();
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
  solGS.save.checkStoredAnalysis().done(function (res) {
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

    solGS.save.checkUserStatus().done(function (res) {
      if (!res.loggedin) {
        solGS.submitJob.loginAlert();
      } else {
      }
    });

    solGS.save.checkUserStatus().fail(function () {
      solGS.alertMessage("Error occured checking for user status");
    });

    solGS.save.getResultDetails().done(function (res) {

      if (res.error) {
        jQuery("#gebvs_output .multi-spinner-container").hide();
        jQuery("#gebvs_save_message")
          .html(res.error + ". The logged info may not exist for the result.")
          .show()
          .fadeOut(50000);

        jQuery("#save_gebvs").show();
      } else {
        var save = solGS.save.saveGebvs(res.analysis_details);

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
