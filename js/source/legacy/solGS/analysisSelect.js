var solGS = solGS || function solGS() { };


solGS.analysisSelect = {

    analysisPopId: null,
    analysisPopname: null,
    analysisType: null,
    dataStructure:null,
    

    
    getAnalysisPopId: function () {
        var analysisPopId = jQuery("#analysis_pop_id").val();
        if (analysisPopId) {
            this.analysisPopId = analysisPopId;
        }
        return this.analysisPopId;
    },

    getAnalysisPopName: function () {
        var analysisPopName = jQuery("#analysis_pop_name").val();
        if (analysisPopName) {
            this.analysisPopname = analysisPopName;
        }
        return this.analysisPopname;
    },

    getAnalysisType: function () {
        var analysisType = jQuery("#analysis_type").val();
        if (analysisType) {
            this.analysisType = analysisType;
        }
        return this.analysisType;
    },

    getDataStructure: function () {
        var dataStructure = jQuery("#data_structure").val();
        if (dataStructure) {
            this.dataStructure = dataStructure;
        }
        return this.dataStructure;
    },

    
}


jQuery(document).on("change", "#analysis_select", function () {
    var selectedAnalysis = jQuery(this).val();
    console.log("Selected analsysis: ", selectedAnalysis);
    
    if (selectedAnalysis) {
        jQuery("#analysis_type").val(selectedAnalysis);
        solGS.analysisSelect.getAnalysisPopId();
        solGS.analysisSelect.getAnalysisPopName();
        solGS.analysisSelect.getAnalysisType();
        solGS.analysisSelect.getDataStructure();
        console.log("Analysis Pop ID: ", solGS.analysisSelect.analysisPopId);
        console.log("Analysis Pop Name: ", solGS.analysisSelect.analysisPopname);
        console.log("Analysis Type: ", solGS.analysisSelect.analysisType);
        console.log("Data Structure: ", solGS.analysisSelect.dataStructure);

    } else {
        console.log("No analysis selected.");
    }
});


jQuery(document).ready(function () {

    jQuery("#run_analysis").on("click", function (e) {

      var analysisType = solGS.analysisSelect.getAnalysisType();
      console.log("Running analysis of type: ", analysisType);


    //   var runCorrBtnId = e.target.id;
  
      var corrArgs;
      var corrPopId;
      if (analysisType.match(/pearson_correlation/)) {
        corrArgs = corrArgs || {};
        jQuery("#corr_pop_id").val(solGS.analysisSelect.getAnalysisPopId());
        // corrArgs.corr_pop_id = solGS.analysisSelect.getAnalysisPopId();
        
        corrArgs = solGS.correlation.getPhenoCorrArgs();
        console.log("Correlation args: ", JSON.stringify(corrArgs));
        corrPopId = corrArgs.corr_pop_id;
  
        // if (!corrPopId) {
        //   corrArgs = solGS.correlation.getSelectedPopCorrArgs(runCorrBtnId);
        // }
      }

      var canvas = solGS.correlation.canvas;
      var corrPlotDivId = solGS.correlation.corrPlotDivPrefix;
      var corrMsgDiv = solGS.correlation.corrMsgDiv;
  
    //   runCorrBtnId = `#${runCorrBtnId}`;
    //   jQuery(runCorrBtnId).hide();
      jQuery(`${canvas} .multi-spinner-container`).show();
      jQuery(corrMsgDiv).html("Running correlation... please wait...").show();
  
      solGS.correlation.runPhenoCorrelation(corrArgs).done(function (res) {
        if (res.data) {
          corrArgs["corr_table_file"] = res.corre_table_file;
          var corrDownload = solGS.correlation.createCorrDownloadLink(corrArgs);
  
          solGS.heatmap.plot(res.data, canvas, corrPlotDivId, corrDownload);
  
          jQuery(`${canvas} .multi-spinner-container`).hide();
          jQuery(corrMsgDiv).empty();
        //   jQuery(runCorrBtnId).show();
        } else {
          jQuery(`${canvas} .multi-spinner-container`).hide();
  
          jQuery(corrMsgDiv).html("There is no correlation output for this dataset.").fadeOut(8400);
  
        //   jQuery(runCorrBtnId).show();
        }
      });
  
      solGS.correlation.runPhenoCorrelation(corrArgs).fail(function (res) {
        jQuery(`${canvas} .multi-spinner-container`).hide();
        jQuery(corrMsgDiv).html("Error occured running the correlation analysis.").fadeOut(8400);
        // jQuery(runCorrBtnId).show();
      });

})

});
