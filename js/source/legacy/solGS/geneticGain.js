/** 
* visualize and compare gebvs of a training population
* and a selection population (genetic gain).
* normal distribution plotting using d3.
* uses methods from solGS.normalDistribution and solGS.linePlot js libraries

* Isaak Y Tecle <iyt2@cornell.edu>
*
*/

var solGS = solGS || function solGS() {};

solGS.geneticGain = {
  canvas: "#gg_canvas",
  ggPlotDivPrefix: "#gg_plot",
  ggMsgDiv: "#gg_message",
  ggPopsDiv: "#gg_pops_select_div",
  ggPopsSelectMenuId: "#gg_pops_select",

  gebvsComparison: function () {
    var gebvParams = this.getGeneticGainArgs();

    var missing;
    if (!gebvParams.training_pop_id) {
      missing = "training population id";
    }

    if (!gebvParams.selection_pop_id) {
      missing += ", selection population id";
    }

    if (!gebvParams.trait_id) {
      missing += ", trait id";
    }

    var ggMsgDiv = this.ggMsgDiv;
    if (missing) {
      jQuery(ggMsgDiv)
        .html("Can not compare GEBVs. I am missing " + missing + ".")
        .show();
    } else {
      this.plotGeneticGainBoxplot(gebvParams);
    }
  },

  getGeneticGainArgs: function () {
    var canvas = this.canvas;
 
    var trainingPopId = jQuery(`${canvas} #training_pop_id`).val();
    var trainingPopName = jQuery(`${canvas} #training_pop_name`).val();
    var selectionPopId = jQuery("#gg_selected_pop_id").val() || jQuery("#selection_pop_id").val();
    var trainingTraitsIds = jQuery(canvas).find("#training_traits_ids").val();
    var traitId = jQuery("#trait_id").val();
    var protocolId = jQuery("#genotyping_protocol_id").val();

    if (document.URL.match(/solgs\/traits\/all\/population\/|solgs\/models\/combined\/trials\//)) {
      if (trainingTraitsIds) {
        trainingTraitsIds = trainingTraitsIds.split(",");
      }
    }

    var ggArgs = {
      training_pop_id: trainingPopId,
      training_pop_name: trainingPopName,
      selection_pop_id: selectionPopId,
      training_traits_ids: trainingTraitsIds,
      trait_id: traitId,
      genotyping_protocol_id: protocolId,
    };

    return ggArgs;
  },

  plotGeneticGainBoxplot: function (ggArgs) {
    var canvas = this.canvas;
    var ggMsgDiv = this.ggMsgDiv;


	ggArgs = JSON.stringify(ggArgs)
    jQuery(` ${canvas} .multi-spinner-container`).show();
    jQuery("#check_genetic_gain").hide();
    jQuery(ggMsgDiv).html("Please wait... plotting genetic gain").show();

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {'arguments': ggArgs},
      url: "/solgs/genetic/gain/boxplot",
      success: function (res) {
        if (res.Error) {
          jQuery(`${canvas} .multi-spinner-container`).hide();
          jQuery(ggMsgDiv).empty();

          solGS.showMessage(ggMsgDiv, res.Error);

          if (
            document.URL.match(
              /\/solgs\/traits\/all\/population\/|solgs\/models\/combined\/trials\//
            )
          ) {
            jQuery("#check_genetic_gain").show();
          }
        } else {
          var boxplot = res.boxplot;
          var boxplotData = res.boxplot_data;
          var plot = '<img  src= "' + boxplot + '">';

          if (boxplot) {
            var fileNameBoxplot = boxplot.split("/").pop();
            boxplotFile = '<a href="' + boxplot + '" download=' + fileNameBoxplot + ">boxplot</a>";

            var fileNameData = boxplotData.split("/").pop();
            var dataFile = '<a href="' + boxplotData + '" download=' + fileNameData + ">Data</a>";
            jQuery("#gg_plot")
              .prepend(
                '<div style="margin-top: 20px">' +
                  plot +
                  "</div>" +
                  "<br /> <strong>Download:</strong> " +
                  boxplotFile +
                  " | " +
                  dataFile
              )
              .show();

            jQuery(`${canvas} .multi-spinner-container`).hide();
            jQuery("#gg_message").empty();

            if (
              document.URL.match(
                /\/solgs\/traits\/all\/population\/|solgs\/models\/combined\/trials\//
              )
            ) {
              jQuery("#check_genetic_gain").show();
            }
          } else {
            jQuery(`${canvas} .multi-spinner-container`).hide();
            showMessage("There is no genetic gain plot for this dataset.");
            jQuery("#check_genetic_gain").show();
          }
        }
      },
      error: function (res) {
        jQuery(`${canvas} .multi-spinner-container`).hide();
        solGS.showMessage(ggMsgDiv, "Error occured plotting the genetic gain.");
        jQuery("#check_genetic_gain").show();
      },
    });
  },

  getTrainingPopulationGEBVs: function (gebvParams) {
    var ggMsgDiv = this.ggMsgDiv;
    gebvParams = JSON.stringify(gebvParams);

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data:{'arguments': gebvParams},
      url: "/solgs/get/gebvs/training/population",
      success: function (res) {
        if (res.gebv_exists) {
          jQuery(ggMsgDiv).empty();
          trainingGEBVs = res.gebv_arrayref;

          if (trainingGEBVs) {
            solGS.geneticGain.getSelectionPopulationGEBVs(gebvParams);
          }
        } else {
          jQuery(ggMsgDiv).html("There is no GEBV data for the training population.").show();
        }
      },
      error: function () {
        jQuery(ggMsgDiv)
          .html("Error occured checking for GEBV data for the training population.")
          .show();
      },
    });
  },

  getSelectionPopulationGEBVs: function (gebvParams) {
    var ggMsgDiv = this.ggMsgDiv;
    gebvParams = JSON.stringify(gebvParams);

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data:{'arguments': gebvParams},
      url: "/solgs/get/gebvs/selection/population",
      success: function (res) {
        if (res.gebv_exists) {
          jQuery(ggMsgDiv).empty();

          selectionGEBVs = res.gebv_arrayref;

          if (selectionGEBVs && trainingGEBVs) {
            jQuery(ggMsgDiv).html("Please wait... plotting gebvs").show();

            solGS.geneticGain.plotGEBVs(trainingGEBVs, selectionGEBVs);

            jQuery(ggMsgDiv).empty();
            jQuery("#check_genetic_gain").hide();
          }
        } else {
          jQuery(ggMsgDiv).html("There is no GEBV data for the selection population.").show();
        }
      },
      error: function () {
        jQuery(ggMsgDiv)
          .html("Error occured checking for GEBV data for the selection population.")
          .show();
      },
    });
  },

  populateGeneticGainMenu: function (newPop) {
    var ggArgs = this.getGeneticGainArgs();

    var ggPops = [];
    if (ggArgs.training_pop_id.match(/list/) == null) {
      var trialSelPopsList = solGS.selectionPopulation.getPredictedTrialTypeSelectionPops();
      if (trialSelPopsList) {
        ggPops.push(trialSelPopsList);
      }
    }

    var menu = new SelectMenu(this.ggPopsDiv, this.ggPopsSelectMenuId);
    
    if (newPop){
        menu.updateOptions(newPop);   
    } else {
      menu.populateMenu(ggPops);
    }

  },

  getSelPopPredictedTraits: function (ggArgs) {
    var ggMsgDiv = this.ggMsgDiv;
	var canvas = this.canvas;

	var args = JSON.stringify(ggArgs);
    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {'arguments': args},
      url: "/solgs/selection/population/predicted/traits",
      success: function (res) {
        if (res.selection_traits) {
          var ggArgs = solGS.geneticGain.getGeneticGainArgs();
          jQuery(`${canvas} #selection_traits_ids`).val(res.selection_traits);
          solGS.geneticGain.plotGeneticGainBoxplot(ggArgs);
        } else {
          jQuery(ggMsgDiv).html("This selection population has no predicted traits.").show();
        }
      },
      error: function () {
        jQuery(ggMsgDiv)
          .html(
            "Error occured checking for predicted traits for the selection population " +
              selectionPopId
          )
          .show();
      },
    });
  },

  plotGEBVs: function (trainingGEBVs, selectionGEBVs) {
    var normalDistTraining = new solGS.normalDistribution();

    var trainingNormalDistData = normalDistTraining.getNormalDistData(trainingGEBVs);

    var gebvZScoresT = normalDistTraining.getYValuesZScores(trainingNormalDistData);

    var yValuesT = normalDistTraining.getPValues(trainingNormalDistData);

    var zScoresPT = normalDistTraining.getZScoresP(trainingNormalDistData);

    var xYT = normalDistTraining.getYValuesP(trainingNormalDistData);

    var xValuesT = normalDistTraining.getYValues(trainingGEBVs);

    var trMean = ss.mean(xValuesT);

    var stdT = trMean <= 0 ? -1.0 : 1.0;

    var xMT = normalDistTraining.getObsValueZScore(gebvZScoresT, stdT);

    var normalDistSelection = new solGS.normalDistribution();

    var selectionNormalDistData = normalDistSelection.getNormalDistData(selectionGEBVs);

    var gebvZScoresS = normalDistSelection.getYValuesZScores(selectionNormalDistData);

    var yValuesS = normalDistSelection.getPValues(selectionNormalDistData);

    var zScoresPS = normalDistSelection.getZScoresP(selectionNormalDistData);

    var xYS = normalDistSelection.getYValuesP(selectionNormalDistData);

    var xValuesS = normalDistSelection.getYValues(selectionGEBVs);

    var slMean = ss.mean(xValuesS);

    var stdS = slMean <= 0 ? -1.0 : 1.0;

    var xMS = normalDistTraining.getObsValueZScore(gebvZScoresS, stdS);

    var svgId = "#compare_gebvs_canvas";
    var plotId = "#compare_gebvs_plot";

    var trColor = "#02bcff";
    var slColor = "#ff1302";
    var axLabelColor = "#ff8d02";
    var yLabel = "Probability";
    var xLabel = "GEBVs";

    var title =
      "Normal distribution curves of GEBVs " + "for the training and selection populations.";

    var allData = {
      div_id: svgId,
      plot_title: title,
      x_axis_label: xLabel,
      y_axis_label: yLabel,
      axis_label_color: axLabelColor,
      lines: [
        {
          data: xYT,
          legend: "Training population",
          color: trColor,
        },
        {
          data: xYS,
          legend: "Selection population",
          color: slColor,
        },
      ],
    };

    var linePlot = solGS.linePlot(allData);

    var trainingMidlineData = [
      [trMean, 0],
      [trMean, d3.max(yValuesT)],
    ];

    var selectionMidlineData = [
      [slMean, 0],
      [slMean, d3.max(yValuesS)],
    ];

    var midLine = d3.svg
      .line()
      .x(function (d) {
        return linePlot.xScale(d[0]);
      })
      .y(function (d) {
        return linePlot.yScale(d[1]);
      });

    linePlot.graph
      .append("path")
      .attr("d", midLine(trainingMidlineData))
      .attr("stroke", trColor)
      .attr("stroke-width", "3")
      .attr("fill", "none")
      .on("mouseover", function (d) {
        if ((d = trMean)) {
          linePlot.graph
            .append("text")
            .attr("id", "tr_mean")
            .text(d3.format(".2f")(trMean))
            .style({
              fill: trColor,
              "font-weight": "bold",
            })
            .attr("x", linePlot.xScale(xMT[0]))
            .attr("y", linePlot.yScale(d3.max(yValuesT) * 0.5));
        }
      })
      .on("mouseout", function () {
        d3.selectAll("text#tr_mean").remove();
      });

    linePlot.graph
      .append("path")
      .attr("d", midLine(selectionMidlineData))
      .attr("stroke", slColor)
      .attr("stroke-width", "3")
      .attr("fill", "none")
      .on("mouseover", function (d) {
        if ((d = slMean)) {
          linePlot.graph
            .append("text")
            .attr("id", "sl_mean")
            .text(d3.format(".2f")(slMean))
            .style({
              fill: slColor,
              "font-weight": "bold",
            })
            .attr("x", linePlot.xScale(xMS[0]))
            .attr("y", linePlot.yScale(d3.max(yValuesS) * 0.5));
        }
      })
      .on("mouseout", function () {
        d3.selectAll("text#sl_mean").remove();
      });
  },

  //////////
};
/////////

jQuery(document).ready(function () {
  jQuery("#check_genetic_gain").on("click", function () {
    var page = document.URL;

    if (page.match(/solgs\/selection\//)) {
      solGS.geneticGain.gebvsComparison();
    } else {
      var selectedPopId = jQuery("#gg_selected_pop_id").val();
      var selectedPopType = jQuery("#gg_selected_pop_type").val();
      var selectedPopName = jQuery("#gg_selected_pop_name").val();

      jQuery("#gg_message")
        .css({ "padding-left": "0px" })
        .html("checking predicted traits for selection population " + selectedPopName);

      var ggArgs = solGS.geneticGain.getGeneticGainArgs();
      solGS.geneticGain.getSelPopPredictedTraits(ggArgs);
    }
  });
});

jQuery(document).ready(function () {
  var page = document.URL;

  if (page.match(/solgs\/traits\/all\/|solgs\/models\/combined\/trials\//) != null) {
    setTimeout(function () {
      solGS.geneticGain.populateGeneticGainMenu();
    }, 5000);
  }
});

jQuery(document).ready(function () {
	var ggPopsDiv = solGS.geneticGain.ggPopsDiv;
	jQuery(ggPopsDiv).change(function () {

	  var selectedPop = jQuery("option:selected", this).data("pop");
  
	  jQuery("#gg_selected_pop_name").val(selectedPop.name);
	  jQuery("#gg_selected_pop_id").val(selectedPop.id);
	  jQuery("#gg_selected_pop_type").val(selectedPop.pop_type);
	});
  
  });
