/**
 * search and display selection populations
 * relevant to a training population.
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.selectionPopulation = {
  checkSelectionPopulations: function () {
    var args = solGS.getModelArgs();
    args = JSON.stringify(args);

    jQuery.ajax({
      type: "POST",
      data: { arguments: args },
      dataType: "json",
      url: "/solgs/check/selection/populations/",
      success: function (response) {
        if (response.data) {
          jQuery("#selection_populations").show();
          jQuery("#search_all_selection_pops").show();

          solGS.selectionPopulation.displaySelectionPopulations(response.data);
        } else {
          jQuery("#search_all_selection_pops").show();
        }
      },
    });
  },

  checkSelectionPopulationRelevance: function (popName) {
    var modelVars = solGS.getModelArgs();
    modelVars["selection_pop_name"] = popName;

    jQuery("#selection_pops_message")
      .html("Checking if the model can be used on " + popName + "...please wait...")
      .show();

    var popData = JSON.stringify(modelVars);
    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: popData },
      url: "/solgs/check/selection/population/relevance/",
      success: function (res) {
        if (res.selection_pop_id) {
          if (res.selection_pop_id != res.training_pop_id) {
            if (res.similarity >= 0.5) {
              jQuery("#selection_pops_message ").hide();
              jQuery("#selection_populations").show();

              var selPopExists = jQuery("#selection_pops_list:contains(" + popName + ")").length;
              if (!selPopExists) {
                solGS.selectionPopulation.displaySelectionPopulations(res.selection_pop_data);
              }
            } else {
              jQuery("#selection_pops_message")
                .html(
                  popName +
                    " is genotyped by a marker set different  " +
                    "from the one used for the training population. " +
                    "Therefore you can not predict its GEBVs using this model."
                )
                .show();
            }
          } else {
            jQuery("#selection_pops_message")
              .html(
                popName +
                  " is the same population as the " +
                  "the training population. " +
                  "Please select a different selection population."
              )
              .show()
              .fadeOut(5000);
          }
        } else {
          jQuery("#selection_pops_message")
            .html(popName + " does not exist in the database.")
            .show()
            .fadeOut(5000);
        }
      },
      error: function (res) {
        jQuery("#selection_pops_message")
          .html("Error occured processing the query.")
          .show()
          .fadeOut(5000);
      },
    });
  },

  searchSelectionPopulations: function () {
    var args = solGS.getModelArgs();

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: args,
      url: "/solgs/search/selection/populations/" + popId,
      success: function (res) {
        if (res.data) {
          jQuery("#selection_populations").show();
          solGS.selectionPopulation.displaySelectionPopulations(res.data);
          jQuery("#search_all_selection_pops").hide();
          jQuery("#selection_pops_message").hide();
        } else {
          var msg =
            "<p>There are no relevant selection populations in the database." +
            "If you have or want to make your own set of selection candidates" +
            "use the form below.</p>";

          jQuery("#selection_pops_message").html(msg).show().fadeOut(5000);
        }
      },
    });
  },

  getPredictedTrialTypeSelectionPops: function () {
    var selPopsTable = jQuery("#selection_pops_list").html();
    var selPopsRows;

    if (selPopsTable !== null) {
      selPopsRows = jQuery("#selection_pops_list").find("tbody > tr");
    }

    var popsList = [];

    for (var i = 0; i < selPopsRows.length; i++) {
      var row = selPopsRows[i];
      var popRow = row.innerHTML;
      var predict = popRow.match(/predict/gi);
      if (!predict) {
        var selPopsInput = row.getElementsByTagName("input")[0];
        var sIndexPopData = selPopsInput.value;
        popsList.push(JSON.parse(sIndexPopData));
      }
    }

    return popsList;
  },

  displaySelectionPopulations: function (data) {
    var tableRow = jQuery("#selection_pops_list tr").length;

    if (tableRow === 1) {
      jQuery("#selection_pops_list").dataTable({
        searching: false,
        ordering: false,
        processing: true,
        paging: false,
        info: false,
        data: data,
      });
    } else {
      jQuery("#selection_pops_list").dataTable().fnAddData(data);
    }
  },

  getPopulationId: function () {
    var populationId = jQuery("#population_id").val();

    if (!populationId) {
      populationId = jQuery("#model_id").val();
    }

    if (!populationId) {
      populationId = jQuery("#combo_pops_id").val();
    }

    return populationId;
  },
};

jQuery(document).ready(function () {
  solGS.selectionPopulation.checkSelectionPopulations();
});

jQuery(document).ready(function () {
  jQuery("#search_all_selection_pops").click(function () {
    solGS.selectionPopulation.searchSelectionPopulations();
    jQuery("#selection_pops_message").html(
      "<br/><br/>Searching for all selection populations relevant to this model...please wait..."
    );
  });
});

jQuery(document).ready(function () {
  jQuery("#population_search_entry").keyup(function (e) {
    jQuery("#population_search_entry").css("border", "solid #96d3ec");

    jQuery("#form-feedback-search-trials").empty();

    if (e.keycode == 13) {
      jQuery("#search_selection_pop").click();
    }
  });

  jQuery("#search_selection_pop").on("click", function () {
    jQuery("#selection_pops_message").hide();

    var entry = jQuery("#population_search_entry").val();

    if (entry) {
      solGS.selectionPopulation.checkSelectionPopulationRelevance(entry);
    } else {
      jQuery("#population_search_entry").css("border", "solid #FF0000");

      jQuery("#form-feedback-search-trials").text("Please enter trial name.");
    }
  });
});
