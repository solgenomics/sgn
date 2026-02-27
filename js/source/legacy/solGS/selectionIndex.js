/**
 * selection index form, calculation and presentation
 * @author Isaak Y Tecle <iyt2@cornell.edu>
 *
 */


var solGS = solGS || function solGS() {};

solGS.sIndex = {
  canvas: "#si_canvas",
  siPlotDivPrefix: "#si_plot",
  siMsgDiv: "#si_message",
  siPopsDiv: "#si_select_pops_div",
  siPopsSelectMenuId: "#si_pops_select",
  siFormId: "#si_form",

  populateSindexMenu: function (newPop) {
    var modelData = solGS.selectMenuModelArgs();

    var sIndexPops = [modelData];

    if (!modelData.id.match(/list/)) {
      var trialSelPopsList = solGS.selectionPopulation.getPredictedTrialTypeSelectionPops();
      if (trialSelPopsList) {
        sIndexPops.push(trialSelPopsList);
      }
    }
    
    var menu = new SelectMenu(this.siPopsDiv, this.siPopsSelectMenuId);

    if (newPop){
        menu.updateOptions(newPop);   
    } else {
      menu.populateMenu(sIndexPops);
    }

  },

  addIndexedClustering: function (indexedPop) {
    // var indexed = solGS.sIndex.indexed;
    // var sIndexList = [];
    // var indexData;
    // if (indexed) {
    //   for (var i = 0; i < indexed.length; i++) {
        return  {
          id: indexedPop.sindex_id,
          name: indexedPop.sindex_name,
          pop_type: "selection_index",
        };

    // //     sIndexList.push(indexData);
    // //   }
    // // }

    // return sIndexList;
  },

  saveIndexedPops: function (siId) {
    solGS.sIndex.indexed.push(siId);
  },

  displaySindexForm: function (modelId, siPopId) {
    if (modelId === siPopId) {
      siPopId = undefined;
    }

    var args = solGS.getModelArgs();
    args.selection_pop_id = siPopId;

    args = JSON.stringify(args);

    var siForm = jQuery.ajax({
      type: "POST",
      dataType: "json",
      url: "/solgs/selection/index/form",
      data: { arguments: args },
    });

    return siForm;
  },

  selectionIndexForm: function (predictedTraits) {
    var trait = "<div>";
    for (var i = 0; i < predictedTraits.length; i++) {
      trait +=
        '<div class="form-group  class="col-sm-3">' +
        '<div  class="col-sm-1">' +
        '<label for="' +
        predictedTraits[i] +
        '">' +
        predictedTraits[i] +
        "</label>" +
        "</div>" +
        '<div  class="col-sm-2">' +
        '<input class="form-control"  name="' +
        predictedTraits[i] +
        '" id="' +
        predictedTraits[i] +
        '" type="text" />' +
        "</div>" +
        "</div>";
    }

    trait +=
      '<div class="col-sm-12">' +
      '<input style="margin: 10px 0 10px 0;"' +
      'class="btn btn-success" type="submit"' +
      'value="Calculate" name= "rank" id="calculate_si"' +
      "/>" +
      "</div>";

    trait += "</div>";

    return trait;
  },

  calcSelectionIndex: function (params, legend, trainingPopId, siPopId) {
    var siArgs = solGS.getModelArgs();

    if (trainingPopId != siPopId) {
      siArgs["selection_pop_id"] = siPopId;
    }

    siArgs["rel_wts"] = params;

    siArgs = JSON.stringify(siArgs);

    var calcSindex = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: siArgs },
      url: "/solgs/calculate/selection/index/",
    });

    return calcSindex;
  },

  validateRelativeWts: function (nm, val) {
    if (isNaN(val) && nm != "all") {
      alert(`the relative weight of trait  ${nm} must be a number.
                    Only numbers and multiplication symbols ('*' or 'x') are allowed.`);
      return;
    } else if (!val && nm != "all") {
      alert(
        "You need to assign a relative weight to trait " +
          nm +
          "." +
          " If you want to exclude the trait assign 0 to it."
      );
      return;
      // }// else if (val < 0 && nm != 'all') {
      //   alert('The relative weight to trait '+nm+
      //         ' must be a positive number.'
      //         );
      //    return;
    } else if (nm == "all" && val == 0) {
      alert("At least two traits must be assigned relative weight.");
      return;
    } else {
      return true;
    }
  },

  sumElements: function (elements) {
    var sum = 0;
    for (var i = 0; i < elements.length; i++) {
      if (!isNaN(elements[i])) {
        sum = parseFloat(sum) + parseFloat(elements[i]);
      }
    }

    return sum;
  },

  selectionIndex: function (trainingPopId, selectionPopId) {
    var legendValues = this.legendParams();

    var legend = legendValues.legend;
    var params = legendValues.params;
    var validate = legendValues.validate;

    if (params && validate) {
      this.calcSelectionIndex(params, legend, trainingPopId, selectionPopId);
    }
  },

  legendParams: function () {
    var siPopName = jQuery("#si_canvas #si_selected_pop_name").val();

    if (!siPopName) {
      siPopName = jQuery("#si_canvas #default_si_selected_pop_name").val();
    }

    var rel_form = document.getElementById("si_form");
    var all = rel_form.getElementsByTagName("input");

    var params = {};
    var validate;
    var allValues = [];

    var trRelWts = "<b>Relative weights</b>:";

    for (var i = 0; i < all.length; i++) {
      var nm = all[i].name;
      var val = all[i].value;
      val = String(val);
      val = val.replace(/x/gi, "*");

      if (val.match(/\*/)) {
        var nums = val.split("*");
        nums = nums.map(Number);
        val = nums[0];
        for (var j = 1; j < nums.length; j++) {
          val = val * nums[j];
        }
      }

      if (val != "Calculate") {
        if (nm != "selection_pop_name") {
          allValues.push(val);
          validate = this.validateRelativeWts(nm, val);

          if (validate) {
            params[nm] = val;
            trRelWts += "<b> " + nm + "</b>" + ": " + val;
          }
        }
      }
    }

    params = JSON.stringify(params);
    var sum = this.sumElements(allValues);
    validate = this.validateRelativeWts("all", sum);

    for (var i = 0; i < allValues.length; i++) {
      // (isNaN(allValues[i]) || allValues[i] < 0)
      if (isNaN(allValues[i])) {
        params = undefined;
      }
    }
    var legend;
    if (siPopName) {
      var popName = "<strong>Population name:</strong> " + siPopName;

      var divId = siPopName.replace(/\s/g, "");
      var relWtsId = trRelWts.replace(/[:\s+relative<>b/weigths]/gi, "");
      legend =
        `<div id="si_legend_${divId}_${relWtsId}">` +
        popName +
        " <strong>|</strong> " +
        trRelWts +
        "</div>";
    }

    return {
      legend: legend,
      params: params,
      validate: validate,
    };
  },

/////
};
////



jQuery(document).ready(function () {
  solGS.sIndex.indexed = [];

  setTimeout(function () {
    solGS.sIndex.populateSindexMenu();
    var modelId = jQuery("#training_pop_id").val();
    var canvas = solGS.sIndex.canvas;
    var siPopsDiv = solGS.sIndex.siPopsDiv;
    var siMsgDiv = solGS.sIndex.siMsgDiv;
    var siFormId = solGS.sIndex.siFormId;

    solGS.sIndex
      .displaySindexForm(modelId, modelId)
      .done(function (res) {
        if (res.status == "success") {
          var table;
          var traits = res.traits;

          if (traits.length > 1) {
            table = solGS.sIndex.selectionIndexForm(traits);
          } else {
            var msg = "There is only one trait with valid GEBV predictions.";
            jQuery(siPopsDiv).empty();
            jQuery(siMsgDiv).empty().append(msg);
          }

          jQuery(`${canvas} ${siFormId}`).empty().append(table);
        }
      })
      .fail(function () {
        var msg = "Error occured creating the selection index form.";
        jQuery(siMsgDiv).empty().append(msg);
      });
  }, 5000);
});

jQuery(document).ready(function () {
  var siPopsDiv = solGS.sIndex.siPopsDiv;
  jQuery(siPopsDiv).change(function () {
    var selectedPop = jQuery("option:selected", this).data("pop");

    var siPopId = selectedPop.id;
    var siPopName = selectedPop.name;
    var selectedPopType = selectedPop.pop_type;
    jQuery("#si_selected_pop_name").val(siPopName);
    jQuery("#si_selected_pop_id").val(siPopId);
    jQuery("#si_selected_pop_type").val(selectedPopType);
  });
});

jQuery(document).on("click", "#calculate_si", function () {
  var canvas = solGS.sIndex.canvas;
  var siMsgDiv = solGS.sIndex.siMsgDiv;

  jQuery(`${canvas} .multi-spinner-container`).show();
  var msg = "Calculating selection index...please wait...";
  jQuery(siMsgDiv).html(msg).show();

  var modelId = jQuery("#training_pop_id").val();
  var siPopId = jQuery(`${canvas} #si_selected_pop_id`).val();
  var popType = jQuery(`${canvas} #si_selected_pop_type`).val();

  solGS.sIndex.selectionIndex(modelId, siPopId);
  var legendValues = solGS.sIndex.legendParams();

  var legend = legendValues.legend;
  var params = legendValues.params;
  var validate = legendValues.validate;
  if (params && validate) {
    solGS.sIndex
      .calcSelectionIndex(params, legend, modelId, siPopId)
      .done(function (res) {
        if (res.status == "success") {
          var sindexFile = res.sindex_file;
          var gebvsSindexFile = res.gebvs_sindex_file;

          var fileNameSindex = sindexFile.split("/").pop();
          var fileNameGebvsSindex = gebvsSindexFile.split("/").pop();
          var sindexLink = `<a href="${sindexFile}" download="${fileNameSindex}">Indices</a>`;
          var gebvsSindexLink = `<a href="${gebvsSindexFile}" download="${fileNameGebvsSindex}">Weighted GEBVs+indices</a>`;

          var sIndexName = res.sindex_name;

          let caption = `<br/><strong>Index Name:</strong> ${sIndexName} <strong>Download:</strong> ${sindexLink} |  ${gebvsSindexLink} ${legend}`;
          let histo = {
            canvas: canvas,
            plot_id: `#${sIndexName}`,
            named_values: res.indices,
            caption: caption,
          };

          solGS.histogram.plotHistogram(histo);

          
          jQuery(siMsgDiv).hide();

          var genArgs = solGS.correlation.getGeneticCorrArgs(
            siPopId,
            popType,
            res.index_file,
            sIndexName
          );
      
          var corrPlotDivId = genArgs.corr_plot_div;
         
          jQuery(`${canvas} .multi-spinner-container`).show();
          jQuery(siMsgDiv).html("Running correlation... please wait...").show();

          solGS.correlation
            .runGeneticCorrelation(genArgs)
            .done(function (res) {
              if (res.status.match(/success/)) {
                genArgs["corr_table_file"] = res.corre_table_file;
                var corrDownload = solGS.correlation.createCorrDownloadLink(genArgs);
                var heatmapArgs = {
                  output_data: res.data,
                  canvas: canvas,
                  plot_div_id: corrPlotDivId,
                  download_links: corrDownload,
                };

                solGS.heatmap.plot(heatmapArgs);
                
                var popName = jQuery("#si_selected_pop_name").val();
                var legendValues = solGS.sIndex.legendParams();

                var popDiv = popName.replace(/\s+/g, "");
                var relWtsId = legendValues.params.replace(/[{",}:\s+<b/>]/gi, "");

                var corLegDiv = `<div id="si_correlation_${popDiv}_${relWtsId}">`;

                var corLegDivVal = jQuery(corLegDiv).html(legendValues.legend);

                jQuery(canvas).append(corLegDivVal).show();
                jQuery(`${canvas} .multi-spinner-container`).hide();
                jQuery(siMsgDiv).empty();
              }
            })
            .fail(function (res) {
              jQuery(siMsgDiv).html("Error occured running correlation analysis.").fadeOut(8400);
            });

          jQuery("#si_canvas #selected_pop").val("");

          var sIndexed = {
            sindex_id: siPopId,
            sindex_name: sIndexName,
          };

          solGS.sIndex.saveIndexedPops(sIndexed);

          // //solGS.cluster.populateClusterMenu();
          var sIndexedPopArgs = solGS.sIndex.addIndexedClustering(sIndexed);
          solGS.cluster.populateClusterMenu(sIndexedPopArgs);
        }
      })
      .fail(function () {
        var msg = "error occured calculating selection index.";
        jQuery(siMsgDiv).html(msg).show();
      });
  }
});

jQuery(document).ready(function () {
  jQuery("#si_tooltip[title]").tooltip();
});
