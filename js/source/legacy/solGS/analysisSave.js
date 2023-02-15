/*
 *Saves solgs modeling output
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.save = {
  checkStoredAnalysis: function () {
    var args = this.saveGebvsArgs();

    var stored = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: { arguments: JSON.stringify(args) },
      url: "/solgs/check/stored/analysis/",
    });

    return stored;
  },

  getResultDetails: function () {
    var args = this.saveGebvsArgs();

    var details = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: { arguments: JSON.stringify(args) },
      url: "/solgs/analysis/result/details",
    });

    return details;
  },

  saveGebvs: function (args) {
    //var args = this.saveGebvsArgs();

    var save = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: args,
      url: "/ajax/analysis/store/json",
    });

    return save;
  },

  saveGebvsArgs: function () {
    var trainingPopId = jQuery("#training_pop_id").val();
    var selectionPopId = jQuery("#selection_pop_id").val();
    var traitId = jQuery("#trait_id").val();
    var protocols = solGS.genotypingProtocol.getPredictionGenotypingProtocols();
    var analysisResultType = this.analysisResultType();

    var args = {
      training_pop_id: trainingPopId,
      selection_pop_id: selectionPopId,
      trait_id: traitId,
      genotyping_protocol_id: protocols.genotyping_protocol_id,
      selection_pop_genotyping_protocol_id: protocols.selection_pop_genotyping_protocol_id,
      analysis_result_type: analysisResultType,
    };

    return args;
  },

  analysisResultType: function () {
    var type;
    var path = location.pathname;

    if (path.match(/solgs\/trait\/\d+\/population\/\d+\//)) {
      type = "training_model";
    } else if (path.match(/solgs\/traits\/all\/population\/\d+\//)) {
      type = "multiple_models";
    } else if (path.match(/solgs\/selection\/\d+\/model\/\d+\//)) {
      type = "selection_prediction";
    }

    return type;
  },

  checkUserStatus: function () {
    return jQuery.ajax({
      type: "POST",
      dataType: "json",
      url: "/solgs/check/user/login/",
    });
  },

  getResultsPageLink: function (id) {
    var link = '<a href="/analyses/' + id + '">View stored GEBVs</a>';
    return link;
  },
};

jQuery(document).ready(function () {
  solGS.save.checkStoredAnalysis().done(function (res) {
    jQuery("#save_gebvs").hide();
    var link = solGS.save.getResultsPageLink(res.analysis_id);
    jQuery("#gebvs_output").append(link);
  });

  jQuery("#save_gebvs").click(function () {
    jQuery("#gebvs_output .multi-spinner-container").show();
    var msg = "Please wait...Analysis results are being stored.";
    jQuery("#gebvs_save_message").html(msg).show();
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
        console.log("getResultDetails " + res.error);
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
            var link = '<a href="/analyses/' + res.analysis_id + '">View stored GEBVs</a>';
            jQuery("#gebvs_output").append(link);
            jQuery("#gebvs_save_message").empty().hide();
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
