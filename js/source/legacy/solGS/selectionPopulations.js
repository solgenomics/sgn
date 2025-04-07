/**
 * search and display selection populations
 * relevant to a training population.
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.selectionPopulation = {
  msgDiv: "#selection_pops_message",
  resultSelDiv: "#selection_pops_result",
  selPopsDiv: "#selection_pops_div",
  searchBtn: "#search_selection_pop",
  searchBox: "#trial_search_box",
  selPopsTable: "#selection_pops_table",
  searchAllSelPops: "#search_all_selection_pops",
  searchFormFeedBack: "#form-feedback-search-trials",

  checkSelectionPopulations: function () {
    var args = solGS.getModelArgs();
    args = JSON.stringify(args);

    var checkPop = jQuery.ajax({
      type: "POST",
      data: { arguments: args },
      dataType: "json",
      url: "/solgs/check/selection/populations/",
    });

    return checkPop;
  },

  checkSelectionPopulationRelevance: function (popName) {
    var modelVars = solGS.getModelArgs();
    modelVars["selection_pop_name"] = popName;

    var popData = JSON.stringify(modelVars);
    var checkRelevance = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: popData },
      url: "/solgs/check/selection/population/relevance/",
    });

    return checkRelevance;
  },

  searchSelectionPopulations: function () {
    var args = solGS.getModelArgs();
    var popId = args.training_pop_id;

    args = JSON.stringify(args);
    var searchPops = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/solgs/search/selection/populations/" + popId,
    });

    return searchPops;
  },

  getPredictedTrialTypeSelectionPops: function () {
    var selPopsTable = jQuery(this.selPopsTable).html();
    var selPopsRows;
    if (selPopsTable !== null) {
      selPopsRows = jQuery(this.selPopsTable).find("tbody > tr");

    }

    var popsList = [];

    for (var i = 0; i < selPopsRows.length; i++) {
      var row = selPopsRows[i];
      var popRow = row.innerHTML;
      var predict = popRow.match(/predict/gi);
      if (!predict) {
        var selPopsInput = row.getElementsByTagName("input")[0];
        var selPopData = selPopsInput.value;

        popsList.push(JSON.parse(selPopData));
      }
    }

    return popsList;
  },

  feedbackOnFail: function (msg) {
    jQuery(this.msgDiv).html(msg).show().fadeOut(8000);
  },

  displaySelectionPopulations: function (data) {
    var tableRow = jQuery(`${this.selPopsTable} tr`).length;

    if (tableRow === 1) {
      jQuery(this.selPopsTable).dataTable({
        searching: false,
        ordering: false,
        processing: true,
        paging: false,
        info: false,
        data: data,
      });
    } else {
      jQuery(this.selPopsTable).dataTable().fnAddData(data);
    }
  },
};

jQuery(document).ready(function () {
  var resultSelDiv = solGS.selectionPopulation.resultSelDiv;
  var msgDiv = solGS.selectionPopulation.msgDiv;
  var searchAllSelPops = solGS.selectionPopulation.searchAllSelPops;
  var searchBox = solGS.selectionPopulation.searchBox;
  var selPopsTable = solGS.selectionPopulation.selPopsTable;
  var selPopsDiv = solGS.selectionPopulation.selPopsDiv;
  var searchBtn = solGS.selectionPopulation.searchBtn;
  var searchFormFeedBack = solGS.selectionPopulation.searchFormFeedBack;

  // jQuery(searchBtn).hide();

  solGS.selectionPopulation
    .checkSelectionPopulations()
    .done(function (res) {
      if (res.data) {
        jQuery(resultSelDiv).show();

        solGS.selectionPopulation.displaySelectionPopulations(res.data);
      } else {
        var msg = "No cached trial for selection prediction found.";
        solGS.selectionPopulation.feedbackOnFail(msg);
      }

      // jQuery(searchBtn).show();
    })
    .fail(function () {
      var msg = "Errro occured querying for selection populations";
      solGS.selectionPopulation.feedbackOnFail(msg);
      // jQuery(searchBtn).show();
    });

  jQuery(searchAllSelPops).click(function () {
    var msg =
      "<br/><br/>Searching for all selection populations relevant to this model...please wait...";
    jQuery(msgDiv).html(msg).show();

    solGS.selectionPopulation
      .searchSelectionPopulations()
      .done(function (res) {
        if (res.data) {
          jQuery(resultSelDiv).show();
          solGS.selectionPopulation.displaySelectionPopulations(res.data);
          jQuery(searchAllSelPops).hide();
          jQuery(this.msgDiv).hide();
        } else {
          var msg =
            "<p>There are no relevant selection populations in the database." +
            "If you have or want to make your own set of selection candidates" +
            "use the form below.</p>";

          jQuery(this.msgDiv).html(msg).show().fadeOut(8000);
        }
      })
      .fail(function () {
        var msg = "Error occured searching for the selection populations.";
        jQuery(this.msgDiv).html(msg).show().fadeOut(8000);
      });
  });

  jQuery(searchBox).keyup(function (e) {
    jQuery(searchBox).css("border", "solid #96d3ec");

    jQuery(searchFormFeedBack).empty();

    if (e.keycode == 13) {
      jQuery(searchBtn).click();
    }
  });

  jQuery(searchBtn).on("click", function () {
    jQuery(searchBtn).hide();

    var popName = jQuery(searchBox).val();
    if (popName) {
      var selPopExists = jQuery(`${selPopsTable}:contains(${popName})`).length;

      if (selPopExists) {
        jQuery(searchBtn).show();
        var msg = `${popName} is already in the search result table`;
        solGS.selectionPopulation.feedbackOnFail(msg);
      } else {
        jQuery(msgDiv)
          .html(`Checking if the model can be used on ${popName} ...please wait...`)
          .show();
        jQuery(`${selPopsDiv} .multi-spinner-container`).show();

        solGS.selectionPopulation
          .checkSelectionPopulationRelevance(popName)
          .done(function (res) {
            if (res.selection_pop_id) {
              if (res.selection_pop_id != res.training_pop_id) {
                if (res.similarity >= 0.5) {
                  jQuery(msgDiv).hide();
                  jQuery(resultSelDiv).show();

                  var selPopExists = jQuery(`${selPopsTable}:contains(${popName})`).length;
                  if (!selPopExists) {
                    solGS.selectionPopulation.displaySelectionPopulations(res.selection_pop_data);
                  }
                } else {
                  var msg = `${popName} is genotyped by a marker set different  
                  from the one used for the training population. Therefore you can not predict its GEBVs using this model.`;

                  solGS.selectionPopulation.feedbackOnFail(msg);
                }
              } else {
                var msg = `${popName} is the same population as the the training population. Please select a different selection population.`;

                solGS.selectionPopulation.feedbackOnFail(msg);
              }
            } else {
              var msg = `${popName} does not exist in the database.`;
              solGS.selectionPopulation.feedbackOnFail(msg);
            }

            jQuery(searchBtn).show();
            jQuery(`${selPopsDiv} .multi-spinner-container`).hide();
          })
          .fail(function () {
            var msg = "Error occured processing the query.";
            solGS.selectionPopulation.feedbackOnFail(msg);
            jQuery(searchBtn).show();
            jQuery(`${selPopsDiv} .multi-spinner-container`).hide();
          });
      }
    } else {
      jQuery(searchBox).css("border", "solid #FF0000");

      jQuery(searchFormFeedBack).text("Please enter trial name.");
      jQuery(searchBtn).show();
    }
  });
});
