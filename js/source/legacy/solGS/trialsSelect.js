var solGS = solGS || function solGS() { };


solGS.trialsSelect = {

    datasetId: null,
    datasetName: null,
    listId: null,
    listName: null,
    dataStructure:null,
    comboPopsId: null,
    comboPopsName: null,


    getComboPopsId: function () {
        var comboPopsId = jQuery("#combo_pops_id").val();
        if (comboPopsId) {
            this.comboPopsId = comboPopsId;
        }
        return this.comboPopsId;
    },
    

    getDatasetId: function () {
        var datasetId = jQuery("#dataset_id").val();
        if (datasetId) {
            this.datasetId = datasetId;
        }
        return this.datasetId;
    },

    getDatasetName: function () {
        var datasetName = jQuery("#dataset_name").val();
        console.log("Dataset Name: ", datasetName);
        if (datasetName) {
            this.datasetName = datasetName;
        }
        return this.datasetName;
    },

    getListId: function () {
        var listId = jQuery("#list_id").val();
        if (listId) {
            this.listId = listId;
        }
        return this.listId;
    },
    
    getListName: function () {
        var listName = jQuery("#list_name").val();
        if (listName) {
            this.listName = listName;
        }
        return this.listName;
    },

    getDataStructure: function () {
        var dataStructure = jQuery("#data_structure").val();
        if (dataStructure) {
            this.dataStructure = dataStructure;
        }
        return this.dataStructure;
    },

    getDatasetTrials: function () {
        var datasetId = this.getDatasetId();
        
        var datasetTrials = jQuery.ajax({
            type: "POST",
            dataType: "json",
            url: "/solgs/get/dataset/trials",
            data: { dataset_id: datasetId }
        });
        return datasetTrials;
    }

}


jQuery(document).ready(function () {
    // Get dataset id
    var datasetId = solGS.trialsSelect.getDatasetId();
    if (datasetId) {
            // Get dataset trials
        solGS.trialsSelect.getDatasetTrials().done(function (res) {
            console.log("Dataset Trials Response: ", res);
            var trials = res.trials_names;
            console.log("Trials found for dataset " + datasetId + ": ", trials);
            
            console.log(typeof trials);
            if (typeof trials === 'string') {
                trials = JSON.parse(trials);
            }

            console.log("Parsed Trials: ", trials);

            if (trials) {
                var datasetName = solGS.trialsSelect.getDatasetName();
                // Process and display the trials
                console.log("Trials for dataset " + datasetName + ": ", trials);
                var trialSelect = jQuery("#trial_select");
                trialSelect.empty(); 

                var datasetOption = jQuery("<option></option>")
                    .attr("value", datasetId)
                    .text("Dataset: " + datasetName);
                trialSelect.append(datasetOption);

                Object.keys(trials).forEach(function (key) {
                    var option = jQuery("<option></option>")
                        .attr("value", key)
                        .text(trials[key]);
                    trialSelect.append(option);
                });
                
            } else {
                console.log("No trials found for dataset " + datasetName);
            }
        }).fail(function () {
            console.error("Failed to retrieve trials for dataset " + datasetName);
        });

    }

});