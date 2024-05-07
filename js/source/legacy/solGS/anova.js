/**
 * single trial ANOVA analysis
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.anova = {
  canvas: "#anova_canvas",
  msgDiv: "#anova_message",
  runDiv: "#run_anova",
  anovaTraitsDiv: "#anova_select_a_trait_div",
  anovaTraitsSelectMenuId: "#anova_select_traits",

  checkTrialDesign: function () {
    var trialId = this.getTrialId();
    var args = JSON.stringify({ trial_id: trialId });

    var trialDesign = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/anova/check/design/",
    });

    return trialDesign;
  },

  anovaAlert: function (msg) {
    var jobSubmit = '<div id= "anova_msg">' + msg + "</div>";

    jQuery(jobSubmit).appendTo("body");

    jQuery("#anova_msg").dialog({
      modal: true,
      title: "Alert",
      buttons: {
        OK: {
          click: function () {
            jQuery(this).dialog("close");
          },
          class: "btn btn-success",
          text: "OK",
        },
      },
    });
  },

  queryPhenoData: function (traitId) {
    var trialId = this.getTrialId();
    var args = JSON.stringify({ trial_id: trialId, trait_id: traitId });

    var phenoData = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/anova/phenotype/data/",
    });

    return phenoData;
  },

  showMessage: function (msg) {
    jQuery(this.msgDiv).html(msg);
  },

  runAnovaAnalysis: function (traits) {
    var trialId = this.getTrialId();
    var captions = jQuery("#anova_table table").find("caption").text();
    var analyzedTraits = captions.replace(/ANOVA result:/g, " ");

    var traitAbbr = traits.trait_abbr;

    if (analyzedTraits.match(traitAbbr) == null) {
      var args = JSON.stringify({ trial_id: trialId, trait_id: traits.trait_id });

      var anovaAnalysis = jQuery.ajax({
        type: "POST",
        dataType: "json",
        data: { arguments: args },
        url: "/anova/analysis/",
      });

      return anovaAnalysis;
    } else {
      jQuery(this.msgDiv).empty();
      jQuery(this.runDiv).show();
      solGS.anova.clearTraitSelection();
    }
  },

  getAnovaTraits: function () {
    var trialId = this.getTrialId();
    var args = JSON.stringify({ trial_id: trialId });

    var anovaTraits = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/anova/traits/list/",
    });

    return anovaTraits;
  },

  populateAnovaMenu: function (traits) {
    var menuId = this.anovaTraitsSelectMenuId;
    var optionsLabel = "Select a trait";
    var menuClass = "form-control";
    var menu = new SelectMenu(menuId, menuClass, optionsLabel);
    traits = traits.flat();
    var menuElem = menu.addOptions(traits);

    var anovaTraitsDiv = this.anovaTraitsDiv;
    jQuery(anovaTraitsDiv).empty().append(menuElem).show();
  },

  clearTraitSelection: function () {
    jQuery("#anova_selected_trait_name").val("");
    jQuery("#anova_selected_trait_id").val("");
  },

  getTrialId: function () {
    var trialId = jQuery("#trial_id").val();

    if (!trialId) {
      trialId = jQuery("#training_pop_id").val();
    }

    return trialId;
  },
};

jQuery(document).ready(function () {
  var url = document.URL;
  var runDiv = solGS.anova.runDiv;
  if (url.match(/\/breeders_toolbox\/trial|breeders\/trial|\/solgs\/population\//)) {
    solGS.anova
      .checkTrialDesign()
      .done(function (designRes) {
        if (designRes.Error) {
          solGS.anova.showMessage(designRes.Error);
          jQuery(runDiv).hide();
        } else {
          solGS.anova
            .getAnovaTraits()
            .done(function (traitsRes) {
              var traits = traitsRes.anova_traits;

              if (traits.length) {
                solGS.anova.populateAnovaMenu(traits);
                jQuery(runDiv).show();
              } else {
                solGS.anova.showMessage("This trial has no phenotyped traits.");
                jQuery(runDiv).hide();
              }
            })
            .fail(function () {
              solGS.anova.showMessage("Error occured listing anova traits.");
              jQuery(runDiv).hide();
            });
        }
      })
      .fail(function () {
        solGS.anova.showMessage("Error occured running the ANOVA.");
        jQuery(runDiv).show();
      });
  }
});

jQuery(document).ready(function () {
  var runDiv = solGS.anova.runDiv;
  var canvas = solGS.anova.canvas;

  jQuery(document).on("click", runDiv, function () {
    var traitId = jQuery("#anova_selected_trait_id").val();
    if (traitId) {
      jQuery(runDiv).hide();
      solGS.anova.showMessage("Please wait...Querying the database for trait data...");
      jQuery(`${canvas} .multi-spinner-container`).show();

      solGS.anova.queryPhenoData(traitId).done(function (queryRes) {
        if (queryRes.Error) {
          solGS.anova.showMessage(queryRes.Error);
          jQuery(runDiv).show();
          jQuery(`${canvas} .multi-spinner-container`).hide();
        } else {
          var traitsAbbrs = queryRes.traits_abbrs;
          traitsAbbrs = JSON.parse(traitsAbbrs);
          solGS.anova.showMessage("Validated trait data...Now running ANOVA...");

          solGS.anova
            .runAnovaAnalysis(traitsAbbrs)
            .done(function (analysisRes) {
              if (analysisRes.Error) {
                jQuery(`${canvas} .multi-spinner-container`).hide();
                jQuery(solGS.anova.msgDiv).empty();
                solGS.anova.showMessage(analysisRes.Error);
                jQuery(runDiv).show();
              } else {
                jQuery(`${canvas} .multi-spinner-container`).hide();
                jQuery(solGS.anova.msgDiv).empty();
                jQuery(runDiv).show();

                var anovaTable = analysisRes.anova_html_table;
                if (anovaTable) {
                  var anovaFile = analysisRes.anova_table_file;
                  var modelFile = analysisRes.anova_model_file;
                  var meansFile = analysisRes.adj_means_file;
                  var diagnosticsFile = analysisRes.anova_diagnostics_file;

                  var fileNameAnova = anovaFile.split("/").pop();
                  var fileNameModel = modelFile.split("/").pop();
                  var fileNameMeans = meansFile.split("/").pop();
                  var fileNameDiagnostics = diagnosticsFile.split("/").pop();
                  anovaFile =
                    '<a href="' + anovaFile + '" download=' + fileNameAnova + ">Anova table</a>";
                  modelFile =
                    '<a href="' + modelFile + '" download=' + fileNameModel + ">Model summary</a>";
                  meansFile =
                    '<a href="' + meansFile + '" download=' + fileNameMeans + ">Adjusted means</a>";

                  diagnosticsFile =
                    '<a href="' +
                    diagnosticsFile +
                    '" download=' +
                    fileNameDiagnostics +
                    ">Model diagnostics</a>";

                  jQuery("#anova_table")
                    .prepend(
                      '<div style="margin-top: 20px">' +
                        anovaTable +
                        "</div>" +
                        "<br /> <strong>Download:</strong> " +
                        anovaFile +
                        " | " +
                        modelFile +
                        " | " +
                        diagnosticsFile +
                        " | " +
                        meansFile
                    )
                    .show();
                } else {
                  jQuery(`${canvas} .multi-spinner-container`).hide();
                  solGS.anova.showMessage("There is no anova output for this dataset.");
                  jQuery(runDiv).show();
                }
              }
            })
            .fail(function () {
              jQuery(`${canvas} .multi-spinner-container`).hide();
              solGS.anova.showMessage("Error occured running the anova analysis.");
              jQuery(runDiv).show();
            });
        }

        solGS.anova.clearTraitSelection();
      });
    } else {
      var msg = "Please select a trait.";
      solGS.anova.anovaAlert(msg);
    }
  });
});

jQuery(document).ready(function () {
  var anovaTraitsDiv = solGS.anova.anovaTraitsDiv;

  jQuery(anovaTraitsDiv).change(function () {
    var selectedTrait = jQuery("option:selected", this).data("pop");
    jQuery("#anova_selected_trait_name").val(selectedTrait.name);
    jQuery("#anova_selected_trait_id").val(selectedTrait.id);
  });
});
