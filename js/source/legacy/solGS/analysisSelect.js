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

    //TODO: check for compatibility with the selected analysis
    if (selectedAnalysis) {
        jQuery("#analysis_type").val(selectedAnalysis)

    } else {
        console.log("No analysis selected.");
    }
});


jQuery(document).ready(function () {

    jQuery("#run_analysis").on("click", function (e) {

        jQuery("#dataset_trials_analysis_message").empty();
        var analysisType = solGS.analysisSelect.getAnalysisType();
        var analysisPopId = solGS.analysisSelect.getAnalysisPopId();

        if (!analysisType) {
        jQuery("#dataset_trials_analysis_message").html("Please select an analysis type.").show();
        }

        if (!analysisPopId) {   
        jQuery("#dataset_trials_analysis_message").html("Please select an analysis population.").show();
        }

        if (analysisType.match(/pearson_correlation/)) {
            var corrArgs;
            var corrPlotDivId;

            jQuery("#corr_pop_id").val(solGS.analysisSelect.getAnalysisPopId());

            jQuery("#data_type").val("Phenotype");
            if (jQuery("#corr_pop_id").val().match(/dataset/) === "") {
            jQuery("#data_structure").val('dataset');
            }

            corrArgs = solGS.correlation.getPhenoCorrArgs();
            if (!corrArgs['corr_pop_name']) {
            corrArgs['corr_pop_name'] = solGS.analysisSelect.getAnalysisPopName();
            }

            console.log("Correlation args: ", JSON.stringify(corrArgs));
            corrPlotDivId = corrArgs.corr_plot_div;

            var canvas = solGS.correlation.canvas;
            var corrMsgDiv = solGS.correlation.corrMsgDiv;

            jQuery(`${canvas} .multi-spinner-container`).show();
            jQuery(corrMsgDiv).html("Running correlation... please wait...").show();

            solGS.correlation.runPhenoCorrelation(corrArgs).done(function (res) {
                if (res.data) {
                    corrArgs["corr_table_file"] = res.corre_table_file;
                    var corrDownload = solGS.correlation.createCorrDownloadLink(corrArgs);

                    solGS.heatmap.plot(res.data, canvas, corrPlotDivId, corrDownload);

                    jQuery(`${canvas} .multi-spinner-container`).hide();
                    jQuery(corrMsgDiv).empty();
                } else {
                    jQuery(`${canvas} .multi-spinner-container`).hide();
                    jQuery(corrMsgDiv).html("There is no correlation output for this dataset.").fadeOut(8400);
                }
            }).fail(function (res) {
                jQuery(`${canvas} .multi-spinner-container`).hide();
                jQuery(corrMsgDiv).html("Error occured running the correlation analysis.").fadeOut(8400);
            });
        }
    })
});
