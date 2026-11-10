var solGS = solGS || function solGS() {};

solGS.dataTableTabs = {
  initialize: function (options) {
    var tabsSelector = "#" + options.prefix + "_population_tabs";
    var panesSelector = "#" + options.prefix + "_pops_data_div";
    var $tabs = jQuery(tabsSelector);
    var $canvas = $tabs.closest("#lists_datasets_canvas");

    var createLoader = function () {
      var $loader = jQuery('<div class="population-tab-loading" style="margin-top:15px"></div>');

      $canvas.find("#lists_datasets_message")
        .clone()
        .removeAttr("id")
        .show()
        .appendTo($loader);

      // css() rather than show(): show() is a no-op on a detached clone hidden by a stylesheet
      $canvas.find("#lists_datasets_progress .multi-spinner-container")
        .first()
        .clone()
        .css("display", "block")
        .appendTo($loader);

      return $loader;
    };

    // The population requests are synchronous, so the loader must be painted
    // before they start, otherwise it never shows up.
    var afterPaint = function (callback) {
      if (window.requestAnimationFrame) {
        window.requestAnimationFrame(function () {
          setTimeout(callback, 0);
        });
      } else {
        setTimeout(callback, 50);
      }
    };

    var loadTab = function ($tab) {
      var paneSelector = $tab.attr("data-target");
      var $pane = jQuery(paneSelector);
      var state = $pane.data("population-table-state");

      if (state === "loading") {
        return;
      }

      if (state === "loaded") {
        var existingTable = $pane.find("table").DataTable();
        existingTable.columns.adjust();
        return;
      }

      $pane.data("population-table-state", "loading");
      $pane.find(".population-tab-error").remove();

      var source = $tab.attr("data-source");
      var ownership = $tab.attr("data-ownership");
      var tableId = options.prefix + "_" + ownership + "_" + source + "_table";
      var $table = jQuery(options.createTable(tableId)).hide();
      var $loader = createLoader();

      $pane.append($loader).append($table);

      // TEMPORARY: simulate slow loading for demo. Remove before committing.
      var testLoadingDelay = 3000;

      afterPaint(function () { setTimeout(function () {
        try {
          var populations = options.getPopulations(source, ownership);
          var rows = options.getRows(populations);
          $table.show();
          options.displayTable(tableId, rows);
          $pane.data("population-table-state", "loaded");
        } catch (error) {
          $table.remove();
          $pane.removeData("population-table-state");
          jQuery('<div class="message population-tab-error" style="margin-top:15px"></div>')
            .text("Error occurred retrieving " + jQuery.trim($tab.text()).toLowerCase() + ". Click the tab to try again.")
            .appendTo($pane);
          console.error(error);
        } finally {
          $loader.remove();
        }
      }, testLoadingDelay); });
    };

    $tabs.off("click.dataTableTabs").on("click.dataTableTabs", "a.population-tab", function (event) {
      event.preventDefault();
      event.stopPropagation();

      var $tab = jQuery(this);
      $tabs.find("li").removeClass("active");
      $tab.parent("li").addClass("active");

      jQuery(panesSelector + " > .tab-pane").removeClass("active").hide();
      jQuery($tab.attr("data-target")).addClass("active").show();

      loadTab($tab);
    });

    jQuery(panesSelector + " > .tab-pane").hide();
    var $activeTab = jQuery(tabsSelector + " li.active a");
    jQuery($activeTab.attr("data-target")).show();
    loadTab($activeTab);
    $canvas.find("#create_new_list_dataset").show();
  }
};
