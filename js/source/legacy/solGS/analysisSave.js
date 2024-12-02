/*
 *Saves solGS modeling and other analysis output
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.save = {
  checkStoredAnalysis: function (analysisArgs) {
    analysisArgs = JSON.stringify(analysisArgs);
    var stored = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: {'arguments': analysisArgs},
      url: "/solgs/check/stored/analysis/",
    });

    return stored;
  },

  getResultDetails: function (analysisArgs) {
    analysisArgs = JSON.stringify(analysisArgs);
    var details = jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: {'arguments': analysisArgs},
      url: "/solgs/analysis/result/details",
    });

    return details;
  },

  storeAnalysisResults: function (args) {
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

