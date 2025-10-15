var solGS = solGS || function solGS() { };


solGS.analysisSelect = {

    analysisPopId: null,
    analysisPopname: null,
    analysisType: null,
    dataStructure:null,
    datasetId: null,
    implementedAnalyses: ['pearson_correlation'],
    compatibilityTools: [
        'Correlation', 
        'Population Structure', 
        'Clustering', 
        'Kinship & Inbreeding'
    ],

    
    getAnalysisPopId: function () {
        var analysisPopId = jQuery("#analysis_pop_id").val();
        if (analysisPopId) {
            this.analysisPopId = analysisPopId;
        }
        return this.analysisPopId;
    },

    getDatasetId: function () {
        var datasetId = jQuery("#dataset_id").val();
        datasetId = datasetId.replace(/dataset_/, '');

        if (datasetId) {
            this.datasetId = datasetId;
        }
        return this.datasetId;
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

    getToolCompatibility: function (datasetId) {

        datasetId = datasetId.replace(/dataset_/, '');

        var toolCompatibility = jQuery.ajax({
            type: "POST",
            url: '/ajax/dataset/retrieve/' + datasetId + '/tool_compatibility',
            dataType: "json",
        });

        return toolCompatibility;
    },

    extractToolsCompatibility: function (toolsCompatibility) {
        toolsCompatibility = toolsCompatibility.tool_compatibility;
        console.log("extractToolsCompatibility Tool Compatibility: ", toolsCompatibility);
        
        toolsCompatibility = JSON.parse(toolsCompatibility);
        var tools = Object.keys(toolsCompatibility);

        console.log("Extracted Tools: ", tools);
        var toolsCompatibilityCheck = {};
        if (tools && tools.length > 0) {
            for (var i = 0; i < tools.length; i++) {
                var tool = tools[i];
                
                var compatible = toolsCompatibility[tool]['compatible'];
                toolsCompatibilityCheck[tool] = compatible;            
            }
        }

        console.log("Tools Compatibility Check: ", toolsCompatibilityCheck);

        return toolsCompatibilityCheck;
},

    
}


jQuery(document).on("change", "#analysis_select", function () {
    var selectedAnalysis = jQuery(this).val();

    jQuery("#dataset_trials_analysis_message").empty();
    jQuery("#run_analysis").prop("disabled", false);
    if (selectedAnalysis) {
        jQuery("#analysis_type").val(selectedAnalysis)
        var datasetId = solGS.analysisSelect.getDatasetId();
        console.log("Dataset ID: ", datasetId);

        implementedAnalyses = solGS.analysisSelect.implementedAnalyses;
        if (!implementedAnalyses.includes(selectedAnalysis)) {
            selectedAnalysis = selectedAnalysis.replace(/_/, ' ');
            jQuery("#dataset_trials_analysis_message").html(
                `This analysis (${selectedAnalysis}) is yet to be implemented.`)
                .show();
            jQuery("#run_analysis").prop("disabled", true);
        }

        if (datasetId) {
            console.log("Dataset ID: ", solGS.analysisSelect.getDatasetId());
            solGS.analysisSelect.getToolCompatibility(datasetId).done(function (toolCompatibility) {
                var toolsCompatibilityCheck = solGS.analysisSelect.extractToolsCompatibility(toolCompatibility);
                
                if (selectedAnalysis.match(/pearson_correlation/)) {
                    var correlationCompatible = toolsCompatibilityCheck['Correlation'];
                    console.log("Correlation Compatible: ", correlationCompatible);

                    if (!correlationCompatible) {
                        population = solGS.analysisSelect.getDataStructure();
                        jQuery("#dataset_trials_analysis_message").html(`<p>
                            This analysis is not compatible with the selected ${population}. <br>
                            Perhaps run 'Check Tool Compatibility', found in the 'Tool Compatibility' <br/>
                            section above, if it may help.</p>`).show();
                        jQuery("#run_analysis").prop("disabled", true);
                    }
                }
                
            }).fail(function () {
                jQuery("#dataset_trials_analysis_message").html("Error retrieving tool compatibility.").show();
            });
        }
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

        console.log("Running analysis: ", analysisType, " on population: ", analysisPopId);
        
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
    });

});
