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
  anovaTableDiv: "#anova_table",
  clearCacheAnova: "#clear_cache_anova",

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
      title: (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_alert_title", "Alert") : "Alert"),
      buttons: {
        OK: {
          click: function () {
            jQuery(this).dialog("close");
          },
          class: "btn btn-success",
          text: (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.ok", "OK") : "OK"),
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
    var captions = jQuery(`${this.anovaTableDiv} table`).find("caption").text();
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
    var selectId = this.anovaTraitsSelectMenuId;
    var menuDivId = this.anovaTraitsDiv;

    var optionsLabel = (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_select_trait", "Select a trait") : "Select a trait");
    var menuClass = "form-control";
    var menu = new SelectMenu(menuDivId, selectId, menuClass, optionsLabel);
    menu.populateMenu(traits)
  
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
                solGS.anova.showMessage((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_no_phenotyped_traits", "This trial has no phenotyped traits.") : "This trial has no phenotyped traits."));
                jQuery(runDiv).hide();
              }
            })
            .fail(function () {
              solGS.anova.showMessage((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_trait_list_error", "Error occurred listing anova traits.") : "Error occurred listing anova traits."));
              jQuery(runDiv).hide();
            });
        }
      })
      .fail(function () {
        solGS.anova.showMessage((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_design_error", "Error occurred running the ANOVA.") : "Error occurred running the ANOVA."));
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
      solGS.anova.showMessage((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_query_wait", "Please wait...querying the database for the trait data...") : "Please wait...querying the database for the trait data..."));
      jQuery(`${canvas} .multi-spinner-container`).show();

      solGS.anova.queryPhenoData(traitId).done(function (queryRes) {
        if (queryRes.Error) {
          solGS.anova.showMessage(queryRes.Error);
          jQuery(runDiv).show();
          jQuery(`${canvas} .multi-spinner-container`).hide();
        } else {
          var traitsAbbrs = queryRes.traits_abbrs;
          traitsAbbrs = JSON.parse(traitsAbbrs);
          solGS.anova.showMessage((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_running_wait", "Validated trait data...now running ANOVA...please wait...") : "Validated trait data...now running ANOVA...please wait..."));

          solGS.anova
            .runAnovaAnalysis(traitsAbbrs)
            .done(function (analysisRes) {
              if (analysisRes.Error) {
                jQuery(`${canvas} .multi-spinner-container`).hide();
                jQuery(solGS.anova.msgDiv).empty();
                solGS.anova.showMessage(analysisRes.Error);
                jQuery(runDiv).show();
                jQuery(solGS.anova.anovaTableDiv).hide();
              } else {
                jQuery(`${canvas} .multi-spinner-container`).hide();
                jQuery(solGS.anova.msgDiv).empty();
                jQuery(runDiv).show();
                jQuery(solGS.anova.anovaTableDiv).show();

                var anovaHtmlTable = analysisRes.anova_table_html_file;
                if (anovaHtmlTable) {
                  var anovaTxtFile = analysisRes.anova_table_txt_file;
                  var modelSummaryFile = analysisRes.anova_model_file;
                  var AdjMeansFile = analysisRes.adj_means_file;
                  var diagnosticsFile = analysisRes.anova_diagnostics_file;

                  var AnovaTxtFileName = anovaTxtFile.split("/").pop();
                  var modelSummaryFileName = modelSummaryFile.split("/").pop();
                  var AdjMeansFileName = AdjMeansFile.split("/").pop();
                  var fileNameDiagnostics = diagnosticsFile.split("/").pop();
                  anovaTxtFile =
                    '<a href="' + anovaTxtFile + '" download=' + AnovaTxtFileName + ">" + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_table_download_link", "Anova table") : "Anova table") + "</a>";
                  modelSummaryFile =
                    '<a href="' + modelSummaryFile + '" download=' + modelSummaryFileName + ">" + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_model_summary_download_link", "Model summary") : "Model summary") + "</a>";
                  AdjMeansFile =
                    '<a href="' + AdjMeansFile + '" download=' + AdjMeansFileName + ">" + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_adjusted_means_download_link", "Adjusted means") : "Adjusted means") + "</a>";

                  diagnosticsFile =
                    '<a href="' +
                    diagnosticsFile +
                    '" download=' +
                    fileNameDiagnostics +
                    ">" + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_model_diagnostics_download_link", "Model diagnostics") : "Model diagnostics") + "</a>";

                  jQuery(solGS.anova.anovaTableDiv)
                    .prepend(
                      '<div style="margin-top: 20px">' +
                        anovaHtmlTable +
                        "</div>" +
                        "<br /> <strong>" + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.download_caption", "Download:") : "Download:") + "</strong> " +
                        anovaTxtFile +
                        " | " +
                        modelSummaryFile +
                        " | " +
                        diagnosticsFile +
                        " | " +
                        AdjMeansFile
                    )
                    .show();
                    jQuery(solGS.anova.clearCacheAnova).removeClass('hidden').show();
                } else {
                  jQuery(`${canvas} .multi-spinner-container`).hide();
                  solGS.anova.showMessage((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_no_output", "There is no anova output for this dataset.") : "There is no anova output for this dataset."));
                  jQuery(runDiv).show();
                }
              }
            })
            .fail(function () {
              jQuery(`${canvas} .multi-spinner-container`).hide();
              solGS.anova.showMessage((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_run_error", "Error occurred running the anova analysis.") : "Error occurred running the anova analysis."));
              jQuery(runDiv).show();
            });
        }

        solGS.anova.clearTraitSelection();
      });
    } else {
      var msg = (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.anova_select_trait_required", "Please select a trait.") : "Please select a trait.");
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
