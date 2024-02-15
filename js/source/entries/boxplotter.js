import BrAPIBoxPlotter from "BrAPI-BoxPlotter";
import "../legacy/d3/d3v4Min.js";
import "../legacy/jquery.js";
import "../legacy/brapi/BrAPI.js";

export function init(main_div) {
    if (!(main_div instanceof HTMLElement)) {
        main_div = document.getElementById(
            main_div.startsWith("#") ? main_div.slice(1) : main_div
        );
    }

    main_div.innerHTML = `
  <div class="container-fluid">
    <div class="row">
      <div class="col-sm-12 boxplotter-loading"></div>
      <div class="form col-sm-12 form-group boxplotter-variable-select-div" style="display:none;">
        <label for="sort" class="control-label">Variable</label>
        <select class="form-control boxplotter-variable-select"></select>
      </div>
    </div>

    <div class="row boxplotter-group-list" style="display:none;">
      <div class="form col-sm-12 form-group">
        <label for="sort" class="control-label"> Group By </label>
        <div class="groupBy-div">
          <select class="form-control groupBy" style="width:auto; display:inline;">
            <option value="" selected></option>
          </select>
          <a class="btn btn-default groupBy-add" style="margin-top:-1px;">+</a>
          <a class="btn btn-default groupBy-remove" style="margin-top:-1px;">-</a>
        </div>
      </div>
    </div>
    
    <div class="row">
      <div class="col-sm-12 boxplotter-result" style="display:none;">
      </div>
    </div>
  </div>`;

    var bp = $(main_div);
    var boxplot = BrAPIBoxPlotter(bp.find(".boxplotter-result").get(0));

    function loadDatasetObsUnits(ds, ou, auth_token) {
        var d = {
            dataset: ds,
        };
        console.log(d);
        bp.find(
            ".boxplotter-variable-select-div, .boxplotter-group-list, .boxplotter-result"
        ).hide();
        bp.find(".boxplotter-loading").html("Loading ...");
        $.ajax({
            url: document.location.origin + "/ajax/tools/boxplotter/get_constraints",
            type: "GET",
            data: d,
            dataType: "json",
            success: function (data) {
                //console.log(data);
                var obsUnits = BrAPI(
                    document.location.origin + "/brapi/v2",
                    "",
                    auth_token
                ).search_observationunits({
                    germplasmDbIds: data["categories"]["accessions"],
                    observationVariableDbIds: data["categories"]["traits"],
                    studyDbIds: data["categories"]["trials"],
                    locationDbIds: data["categories"]["locations"],
                    programDbIds: data["categories"]["breeding_programs"],
                    observationLevelName: ou,
                    includeObservations: "true",
                    pageSize: 100000,
                });
                boxplot.setData(obsUnits);
                obsUnits.all(function (d) {
                    console.log(d);
                });
                drawVariableSelect();
                drawGroupBys();
                boxplot.getVariables().then((vs) => {
                    if (vs.length < 1) {
                        bp.find(".boxplotter-result").html(
                            '<strong class="not-enough-data">Not Enough Data with the Given Constraints</strong>'
                        );
                        bp.find(".boxplots").hide();
                    } else {
                        readGrouping();
                        bp.find(".boxplotter-result .not-enough-data").remove();
                        bp.find(
                            ".boxplotter-variable-select-div, .boxplotter-group-list, .brapp-wrapper, .boxplots"
                        ).show();
                    }
                    bp.find(".boxplotter-loading").html("");
                    bp.find(".boxplotter-result").show();
                });
            },
        });
    }
    function drawVariableSelect() {
        boxplot.getVariables().then((vs) => {
            var vars = d3
                .select(main_div)
                .select(".boxplotter-variable-select")
                .selectAll("option")
                .data(vs);
            vars.exit().remove();
            var allVars = vars
                .enter()
                .append("option")
                .merge(vars)
                .attr("value", (d) => d.key)
                .attr("selected", (d) => (d.key == boxplot.variable ? "" : null))
                .text((d) => d.value);
        });
        d3.select(main_div)
            .select(".boxplotter-variable-select")
            .on("change", function () {
                boxplot.setVariable(this.value);
            });
    }

    function drawGroupBys() {
        boxplot.getGroupings().then((grps) => {
            console.log("grps", grps);
            var optSelects = d3
                .select(main_div)
                .select(".boxplotter-group-list")
                .selectAll(".groupBy")
                .on("change", function () {
                    readGrouping();
                })
                .selectAll('option:not([value=""])')
                .data((d) => grps);
            optSelects
                .enter()
                .append("option")
                .merge(optSelects)
                .attr("value", (d) => d.key)
                .text((d) => d.value.name);
            d3.selectAll(".groupBy-add").on("click", function () {
                $(this.parentNode).clone(true).appendTo(this.parentNode.parentNode);
                drawGroupBys();
                readGrouping();
            });
            d3.selectAll(".groupBy-remove").on("click", function () {
                d3.select(this.parentNode).remove();
                readGrouping();
            });
        });
    }
    function readGrouping() {
        var grouping = [];
        d3.selectAll(".groupBy").each(function () {
            grouping.push(this.value);
        });
        boxplot.setGroupings(grouping);
    }

    return {
        loadDatasetObsUnits: loadDatasetObsUnits,
        boxplot: boxplot,
        element: main_div,
    };
}
