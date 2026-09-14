var solGS = solGS || function solGS() {};

solGS.dataTableTabs = {
  initialize: function (options) {
    var tabsSelector = "#" + options.prefix + "_population_tabs";
    var panesSelector = "#" + options.prefix + "_pops_data_div";
    var $tabs = jQuery(tabsSelector);
    var $canvas = $tabs.closest("#lists_datasets_canvas");

    var loadTab = function ($tab) {
      var paneSelector = $tab.attr("data-target");
      var $pane = jQuery(paneSelector);

      if ($pane.data("population-table-loaded")) {
        var existingTable = $pane.find("table").DataTable();
        existingTable.columns.adjust();
        return;
      }

      $pane.data("population-table-loaded", true);

      var source = $tab.attr("data-source");
      var ownership = $tab.attr("data-ownership");
      var tableId = options.prefix + "_" + ownership + "_" + source + "_table";
      var table = options.createTable(tableId);

      $pane.append(table);
      $canvas.find("#lists_datasets_message").show();
      $canvas.find("#lists_datasets_progress .multi-spinner-container").show();

      try {
        var populations = options.getPopulations(source, ownership);
        var rows = options.getRows(populations);
        options.displayTable(tableId, rows);
        if (options.afterDisplay) {
          options.afterDisplay(populations, rows, tableId);
        }
      } finally {
        $canvas.find("#lists_datasets_message").hide();
        $canvas.find("#lists_datasets_progress .multi-spinner-container").hide();
      }
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
