/**
 * Principal component analysis and scores plotting
 * using d3js
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() { };

solGS.pca = {
    canvas: "#pca_canvas",
    pcaPlotDivPrefix: "#pca_plot",
    pcaMsgDiv: "#pca_message",
    pcaPopsDiv: "#pca_pops_select_div",
    pcaPopsSelectMenuId: "#pca_pops_select",
    pcaPopsDataDiv: "#pca_pops_data_div",

    pcaPlotDivId: function (fileId) {
        return `${this.pcaPlotDivPrefix}_${fileId}`;
    },

    getPcaAnalysisArgs: function (pcaAnalysisElemId) {
        var pcaArgs;

        var url = location.pathname;

        if (url.match(/pca\/analysis/)) {
            if (pcaAnalysisElemId) {
                pcaArgs = solGS.pca.getSelectedPopPcaArgs(pcaAnalysisElemId);
            }
            
            if (!pcaArgs) {
                pcaArgs = this.getArgsFromPcaUrl();
            }
            

        } else {
            pcaArgs = this.getArgsFromOtherUrls();
        }

        return pcaArgs;
    },

    getArgsFromOtherUrls: function () {
        var protocolId =
            solGS.genotypingProtocol.getGenotypingProtocolId("pca_div");

        var pcaPopId;
        var selectionPopId;
        var trainingPopId;
        var dataStr;

        var page = location.pathname;
        if ( page.match(/solgs\/trait\/|solgs\/model\/combined\/trials\/|\/breeders\/trial\//)
) {
            trainingPopId = jQuery("#training_pop_id").val();
            if (!trainingPopId) {
                trainingPopId = jQuery("#trial_id").val();
            }
            pcaPopId = trainingPopId;
            if (trainingPopId.match(/list/)) {
                dataStr = "list";
            } else if (pcaPopId.match(/dataset/)) {
                dataStr = "dataset";
            }
        } else if (page.match(/\/selection\/|\/prediction\//)) {
            selectionPopId = jQuery("#selection_pop_id").val();
            pcaPopId = selectionPopId;
            trainingPopId = jQuery("#training_pop_id").val();
            pcaPopId = `${trainingPopId}-${selectionPopId}`;
            if (selectionPopId.match(/list/)) {
                dataStr = "list";
            } else if (pcaPopId.match(/dataset/)) {
                dataStr = "dataset";
            }
        } else if (
            page.match(
                /solgs\/traits\/all\/population\/|models\/combined\/trials\//
            )
        ) {
            pcaPopId = trainingPopId;
        }

        var traitId = jQuery("#trait_id").val();

        if (page.match(/combined/)) {
            var dataSetType = "combined_populations";
            var comboPopsId = trainingPopId;
            if (comboPopsId) {
                var dataSetType = "combined_populations";
            }
        }

        var dataType = this.getSelectedDataType(pcaPopId);
        var analysisPage = this.generatePcaUrl(pcaPopId);
        pcaArgs = {
            pca_pop_id: pcaPopId,
            training_pop_id: trainingPopId,
            combo_pops_id: comboPopsId,
            selection_pop_id: selectionPopId,
            data_structure: dataStr,
            data_type: dataType,
            data_set_type: dataSetType,
            genotyping_protocol_id: protocolId,
            trait_id: traitId,
            analysis_page: analysisPage,
            analysis_type: "pca analysis",
        };

        return pcaArgs;
    },

    getArgsFromPcaUrl: function () {
        var page = location.pathname;
        if (page == "/pca/analysis/") {
            page = "/pca/analysis";
        }

        var urlArgs = page.replace("/pca/analysis", "");
        var pcaPopId;
        var traitId;
        var protocolId;

        if (urlArgs) {
            var args = urlArgs.split(/\/+/);
            if (urlArgs.match(/trait/)) {
                pcaPopId = args[1];
                traitId = args[3];
                protocolId = args[5];
            } else {
                pcaPopId = args[1];
                protocolId = args[3];
            }

            var dataType;
            if (protocolId) {
                dataType = "Genotype";
            } else {
                dataType = "Phenotype";
            }

            var dataStr;
            var listId;
            var datasetId;

            if (pcaPopId.match(/dataset/)) {
                dataStr = "dataset";
                datasetId = pcaPopId.replace(/\d+-\w+_|w+_/g, "");
            } else if (pcaPopId.match(/list/)) {
                dataStr = "list";
                listId = pcaPopId.replace(/\d+-\w+_|\w+_/, "");
            }

            var args = {
                pca_pop_id: pcaPopId,
                list_id: listId,
                trait_id: traitId,
                dataset_id: datasetId,
                data_structure: dataStr,
                data_type: dataType,
                analysis_type: "pca analysis",
                analysis_page: page,
            };

            if (protocolId) {
                args.genotyping_protocol_id = protocolId;
            }

            var reg = /\d+-+\d+/;
            if (pcaPopId.match(reg)) {
                var ids = pcaPopId.split("-");
                args["training_pop_id"] = ids[0];
                args["selection_pop_id"] = ids[1];
            }
            
            return args;
        } else {
            return {};
        }
    },

    getRunPcaId: function (pcaPopId) {
        if (pcaPopId) {
            return `run_pca_${pcaPopId}`;
        } else {
            return "run_pca";
        }
    },

    getSelectedPopPcaArgs: function (runPcaElemId) {
        var pcaArgs;
        var selectedPopDiv = document.getElementById(runPcaElemId);

        if (selectedPopDiv) {
            var selectedPopData = selectedPopDiv.dataset;
            var selectedPop = JSON.parse(selectedPopData.selectedPop);
            pcaPopId = selectedPop.pca_pop_id;

            var pcaArgs = selectedPopData.selectedPop;
            pcaArgs = JSON.parse(pcaArgs);
            if (!selectedPop.data_type) {
                pcaArgs["data_type"] = this.getSelectedDataType(pcaPopId);
            }

            if (!runPcaElemId.match(/save_pcs/)) {
                pcaArgs["analysis_page"] = this.generatePcaUrl(pcaPopId);
            }
        }

        return pcaArgs;
    },

    getPcaPopId: function (selectedId, dataStr) {
        var pcaPopId;
        if (dataStr) {
            pcaPopId = `${dataStr}_${selectedId}`;
        } else {
            pcaPopId = selectedId;
        }

        return pcaPopId;
    },



  createRowElements: function (pcaPop) {
    var popId = pcaPop.id;
    var popName = pcaPop.name;
    var dataStr = pcaPop.data_str;
    
    var pcaPopId = solGS.pca.getPcaPopId(popId, dataStr);

    var dataTypes;
    if (location.pathname.match(/pca\/analysis/)) {
        dataTypes = pcaPop.data_type;
    } else {
        dataTypes = this.getDataTypeOpts();
    }

    var dataTypeOpts = this.createDataTypeSelect(dataTypes, pcaPopId);

    var runPcaBtnId = this.getRunPcaId(pcaPopId);

    var listId;
    var datasetId;

    if (dataStr.match(/dataset/)) {
        datasetId = popId;
    } else if (dataStr.match(/list/)) {
        listId = popId;
    }
    var protocolId =
        solGS.genotypingProtocol.getGenotypingProtocolId("pca_div");

    var pcaArgs = {
        pca_pop_id: pcaPopId,
        data_structure: dataStr,
        dataset_id: datasetId,
        list_id: listId,
        pca_pop_name: popName,
        genotyping_protocol_id: protocolId,
        analysis_type: "pca analysis",
    };

    pcaArgs = JSON.stringify(pcaArgs);

    var runPcaBtn =
        `<button type="button" id=${runPcaBtnId}` +
        ` class="btn btn-success" data-selected-pop='${pcaArgs}'>Run PCA</button>`;

    var compatibilityMessage = '';
    if (dataStr.match(/dataset/)) {
        popName = `<a href="/dataset/${popId}">${popName}</a>`;
        var toolCompatibility = pcaPop.toolCompatibility;
        compatibilityMessage = this.toolCompatibilityMessage(toolCompatibility, dataStr);

    }

    var trId = pcaPopId;
    var rowData = [
        popName,
        dataStr,
        compatibilityMessage, 
        pcaPop.owner,
        dataTypeOpts,
        runPcaBtn,
        trId,
    ];

    return rowData;

    },

    toolCompatibilityMessage: function (toolCompatibility, dataStr) {
        var compatibilityMessage = '';

        if (dataStr.match(/dataset/)) {
            if (toolCompatibility == null || toolCompatibility == "(not calculated)"){
            compatibilityMessage = "(not calculated)";
        } else {
            if (toolCompatibility["Population Structure"]['compatible'] == 0) {
            compatibilityMessage = '<b><span class="glyphicon glyphicon-remove" style="color:red"></span></b>'
            } else {
                if ('warn' in toolCompatibility["Population Structure"]) {
                    compatibilityMessage = '<b><span class="glyphicon glyphicon-warning-sign" style="color:orange;font-size:14px" title="' + toolCompatibility["Population Structure"]['warn'] + '"></span></b>';
                } else {
                    compatibilityMessage = '<b><span class="glyphicon glyphicon-ok" style="color:green" title="'+toolCompatibility["Population Structure"]['types']+'"></span></b>';
                }
            }
        }
        }
        console.log(`compatibilityMessage: ${compatibilityMessage}`);
        return compatibilityMessage;
    },

    displayPcaPopsTable: function (tableId, data) {
        var table = jQuery(`#${tableId}`).DataTable({
            searching: true,
            ordering: true,
            processing: true,
            paging: true,
            info: false,
            pageLength: 5,
            'lengthMenu': [
                [5,10,50,100,-1],[5,10,50,100,'All']
            ],
            'rowId': function (a) {
                return a[6];
            }
       
        });

        table.rows.add(data).draw();
    },

    getPcaPopsRows: function (pcaPops) {
        var pcaPopsRows = [];

        for (var i = 0; i < pcaPops.length; i++) {
            if (pcaPops[i]) {
                var pcaPopRow = this.createRowElements(pcaPops[i]);
                pcaPopsRows.push(pcaPopRow);
            }
        }

        return pcaPopsRows;
    },

    getPcaPops: function () {
        var list = new solGSList();
        var lists = list.getLists(["accessions", "plots", "trials"]);
        lists = list.addDataStrAttr(lists);
        lists = list.addDataTypeAttr(lists, "");
        var datasets = solGS.dataset.getDatasetPops(["accessions", "trials"]);

        datasets = solGS.dataset.addDataTypeAttr(datasets, "Population Structure");
        var pcaPops = [lists, datasets];

        return pcaPops.flat();
    },

    getDataTypeOpts: function () {
        var dataTypeOpts = [];

        if (location.pathname.match(/breeders\/trial/)) {
            dataTypeOpts = ["Genotype", "Phenotype"];
        } else if (
            page.match(
                /solgs\/trait\/\d+\/population\/|solgs\/model\/combined\/trials\//
            )
        ) {
            dataTypeOpts = ["Genotype"];
        }

        return dataTypeOpts;
    },

    checkCachedPca: function (pcaArgs) {
        if (document.URL.match(/pca\/analysis/)) {
            var message = this.validatePcaParams(pcaArgs);

            if (message) {
                jQuery(this.pcaMsgDiv)
                    .prependTo(jQuery(this.canvas))
                    .html(message)
                    .show()
                    .fadeOut(9400);
            }
        }

        var page = pcaArgs.analysis_page;
        pcaArgs = JSON.stringify(pcaArgs);

        var checkCache = jQuery.ajax({
            type: "POST",
            dataType: "json",
            data: {
                page: page,
                arguments: pcaArgs,
            },
            url: "/solgs/check/cached/result/",
        });

        return checkCache;
    },

    pcaDataTypeSelectId: function (pcaPopId) {
        if (location.pathname.match(/pca\/analysis/) && pcaPopId) {
            return `pca_data_type_select_${pcaPopId}`;
        } else {
            return "pca_data_type_select";
        }
    },

    getSelectedDataType: function (pcaPopId) {
        var dataType;
        if (pcaPopId) {
            var pcaDataSelectedId = this.pcaDataTypeSelectId(pcaPopId);
            dataType = jQuery("#" + pcaDataSelectedId).val();
        } else {
            dataType = jQuery("#pca_data_type_select").val();
        }

        return dataType;
    },

    runPcaAnalysis: function (pcaArgs) {
        pcaArgs = JSON.stringify(pcaArgs);

        var pcaAnalysis = jQuery.ajax({
            type: "POST",
            dataType: "json",
            data: {
                arguments: pcaArgs,
            },
            url: "/run/pca/analysis",
        });

        return pcaAnalysis;
    },

    validatePcaParams: function (valArgs) {
        var dataType = valArgs.data_type;
        var dataStr = valArgs.data_structure;
        var pcaPopId = valArgs.pca_pop_id;
        var msg;

        if (dataStr && dataStr.match("list")) {
            var listId = pcaPopId.replace(/\d+-\w+_|\w+_/g, "");
            var list = new CXGN.List();
            var listType = list.getListType(listId);

            if (listType.match(/accessions/) && dataType.match(/phenotype/i)) {
                msg =
                    "With list of clones, you can only do PCA based on <em>genotype</em>.";
            }

            if (listType.match(/plots/) && dataType.match(/genotype/i)) {
                msg =
                    "With list of plots, you can only do PCA based on <em>phenotype</em>.";
            }
        }

        return msg;
    },

    createTable: function (tableId) {
        var pcaTable =
            `<table id="${tableId}" class="table table-striped"><thead><tr>` +
            "<th>Population</th>" +
            "<th>Data structure type</th>" +
            "<th>Compatibility</th>" +
      "<th>Ownership</th>" +
            "<th>Data type</th>" +
            "<th>Run PCA</th>" +
            "</tr></thead></table>";

        return pcaTable;
    },

    createDataTypeSelect: function (opts, pcaPopId) {
        var pcaDataTypeId = this.pcaDataTypeSelectId(pcaPopId);
        var dataTypeGroup =
            '<select class="form-control" id="' + pcaDataTypeId + '">';

        for (var i = 0; i < opts.length; i++) {
            dataTypeGroup +=
                '<option value="' + opts[i] + '">' + opts[i] + "</option>";
        }
        dataTypeGroup += "</select>";

        return dataTypeGroup;
    },

    pcaDownloadLinks: function (res) {
        var screePlotFile = res.scree_plot_file;
        var scoresFile = res.scores_file;
        var loadingsFile = res.loadings_file;
        var variancesFile = res.variances_file;

        var screePlot = screePlotFile.split("/").pop();
        var screePlotLink =
            '<a href="' +
            screePlotFile +
            '" download=' +
            screePlot +
            ">Scree plot</a>";

        var scores = scoresFile.split("/").pop();
        var scoresLink =
            '<a href="' + scoresFile + '" download=' + scores + "> Scores </a>";

        var loadings = loadingsFile.split("/").pop();
        var loadingsLink =
            '<a href="' +
            loadingsFile +
            '" download=' +
            loadings +
            ">Loadings</a>";

        var variances = variancesFile.split("/").pop();
        var variancesLink =
            '<a href="' +
            variancesFile +
            '" download=' +
            variances +
            ">Variances</a>";

        var pcaPlotDivId = this.pcaPlotDivId(res.file_id).replace(/#/, "");
        var pcaPlotLink = `<a href='#'  onclick='event.preventDefault();' id='download_${pcaPlotDivId}'>PCA plot</a>`;

        var runPcaBtnId;// = this.getRunPcaId(res.pca_pop_id);

        var isPcaResultPage = location.pathname.replace(/pca\/analysis/, "");
        isPcaResultPage = isPcaResultPage.replace(/\//g, "");
        if (isPcaResultPage) {
            runPcaBtnId = pcaPlotDivId.replace('pca_plot', 'run_pca')   
        } else {
            runPcaBtnId = this.getRunPcaId(res.pca_pop_id);
        }

        var pcaArgs = this.getPcaAnalysisArgs(runPcaBtnId);
        pcaArgs["file_id"] = res.file_id;
        pcaArgs = JSON.stringify(pcaArgs);

        var savePcs;
        if (res.analysis_name) {
            savePcs = `<button id="save_pcs_btn_${res.file_id}" class="btn btn-success" data-selected-pop='${pcaArgs}'>Save PCs</button>`;
        }

        var downloadLinks =
            `<div class="download_pca_output">` +
            screePlotLink +
            " | " +
            scoresLink +
            " | " +
            variancesLink +
            " | " +
            loadingsLink +
            " | " +
            pcaPlotLink;

        if (savePcs) {
            downloadLinks += " | " + savePcs;
        }

        downloadLinks += "</div>";

        return downloadLinks;
    },

    structurePlotData: function (res) {
        var listId = res.list_id;
        var listName;

        if (listId) {
            var list = new CXGN.List();
            listName = list.listNameById(listId);
            res["list_id"] = listId;
            res["list_name"] = listName;
        }

        return res;
    },

    generatePcaUrl: function (pcaPopId) {
        var traitId = jQuery("#trait_id").val();
        var protocolId =
            solGS.genotypingProtocol.getGenotypingProtocolId("pca_div");

        var solgsPages =
            "solgs/population/" +
            "|solgs/populations/combined/" +
            "|solgs/trait/" +
            "|solgs/model/combined/trials/" +
            "|solgs/selection/\\d+|\\w+_\\d+/model/" +
            "|solgs/combined/model/\\d+|\\w+_\\d+/selection/" +
            "|solgs/models/combined/trials/" +
            "|solgs/traits/all/population/";

        var url = "/pca/analysis/" + pcaPopId;

 
        if (location.pathname.match(solgsPages)) {
            url = url + "/trait/" + traitId;
        }


        var pcaDataSelectedId = this.pcaDataTypeSelectId(pcaPopId);
        dataType = jQuery("#" + pcaDataSelectedId).val();
        
        if (dataType.match(/genotype/i) && protocolId) {
            url = url + "/gp/" + protocolId;
        }

        return url;
    },

    cleanUpOnSuccess: function (pcaPopId) {
        jQuery(this.pcaMsgDiv).empty();
        jQuery(`${this.canvas} .multi-spinner-container`).hide();
        jQuery(`#${this.getRunPcaId(pcaPopId)}`).show();
    },

    feedBackOnFailure: function (pcaPopId, msg) {
        jQuery(`${this.canvas} .multi-spinner-container`).hide();

        jQuery(this.pcaMsgDiv).html(msg).fadeOut(8400);

        jQuery(`#${this.getRunPcaId(pcaPopId)}`).show();
    },

    plotPca: function (plotData, downloadLinks) {
        var scores = plotData.scores;
        var variances = plotData.variances;
        var loadings = plotData.loadings;
        var trialsNames = plotData.trials_names;

        var pc12 = [];
        var pc1 = [];
        var pc2 = [];
        var trials = [];

        jQuery.each(scores, function (i, pc) {
            pc12.push([
                {
                    name: pc[0],
                    pc1: parseFloat(pc[2]),
                    pc2: parseFloat(pc[3]),
                    trial: pc[1],
                },
            ]);
            pc1.push(parseFloat(pc[2]));
            pc2.push(parseFloat(pc[3]));

            if (!trials.includes(pc[1])) {
                trials.push(pc[1]);
            }
        });

        var height = 400;
        var width = 400;
        var pad = {
            left: 60,
            top: 20,
            right: 40,
            bottom: 20,
        };
        var totalH = height + pad.top + pad.bottom + 100;
        var totalW = width + pad.left + pad.right + 400;

        var pcaCanvasDivId = this.canvas;
        var pcaPlotDivId = this.pcaPlotDivId(plotData.file_id);

        pcaPlotDivId = pcaPlotDivId.replace(/#/, "");
        jQuery(pcaCanvasDivId).append("<div id=" + pcaPlotDivId + "></div>");

        pcaPlotDivId = "#" + pcaPlotDivId;
        var svg = d3
            .select(pcaPlotDivId)
            .insert("svg", ":first-child")
            .attr("width", totalW)
            .attr("height", totalH);

        var pcaPlot = svg
            .append("g")
            .attr("id", pcaPlotDivId)
            .attr("transform", "translate(0,0)");

        var pc1Min = d3.min(pc1);
        var pc1Max = d3.max(pc1);

        var pc1Limits = d3.max([Math.abs(d3.min(pc1)), d3.max(pc1)]);
        var pc2Limits = d3.max([Math.abs(d3.min(pc2)), d3.max(pc2)]);

        var pc1AxisScale = d3
            .scaleLinear()
            .domain([0, pc1Limits])
            .range([0, width / 2]);

        var pc1AxisLabel = d3
            .scaleLinear()
            .domain([-1 * pc1Limits, pc1Limits])
            .range([0, width]);

        var pc2AxisScale = d3
            .scaleLinear()
            .domain([0, pc2Limits])
            .range([0, height / 2]);

        var pc1Axis = d3.axisBottom(pc1AxisLabel).tickSize(3);

        var pc2AxisLabel = d3
            .scaleLinear()
            .domain([-1 * pc2Limits, pc2Limits])
            .range([height, 0]);

        var pc2Axis = d3.axisLeft(pc2AxisLabel).tickSize(3);

        var pc1AxisMid = 0.5 * height + pad.top;
        var pc2AxisMid = 0.5 * width + pad.left;

        var verMidLineData = [
            {
                x: pc2AxisMid,
                y: pad.top,
            },
            {
                x: pc2AxisMid,
                y: pad.top + height,
            },
        ];

        var rightNudge = 5;
        var horMidLineData = [
            {
                x: pad.left,
                y: pad.top + height / 2,
            },
            {
                x: pad.left + width + rightNudge,
                y: pad.top + height / 2,
            },
        ];

        var lineFunction = d3
            .line()
            .x(function (d) {
                return d.x;
            })
            .y(function (d) {
                return d.y;
            });
        // .interpolate("linear");

        var pc1Color = "green";
        var pc2Color = "red";
        var axisValColor = "#86B404";
        var labelFs = 12;

        pcaPlot
            .append("g")
            .attr("class", "PC1 axis")
            .attr(
                "transform",
                "translate(" + pad.left + "," + (pad.top + height) + ")"
            )
            .call(pc1Axis)
            .selectAll("text")
            .attr("y", 0)
            .attr("x", 10)
            .attr("dy", ".1em")
            .attr("transform", "rotate(90)")
            .attr("fill", pc1Color)
            .style({
                "text-anchor": "start",
                fill: axisValColor,
            });

        pcaPlot
            .append("g")
            .attr("transform", "translate(" + pc1AxisMid + "," + height + ")")
            .append("text")
            .text("PC1 (" + variances[0][1] + "%)")
            .attr("y", pad.top + 40)
            .attr("x", 0)
            .attr("font-size", labelFs)
            .style("fill", pc1Color);

        pcaPlot
            .append("g")
            .attr("transform", "translate(" + pad.left + "," + pc2AxisMid + ")")
            .append("text")
            .text("PC2 (" + variances[1][1] + "%)")
            .attr("y", -40)
            .attr("x", 0)
            .attr("transform", "rotate(-90)")
            .attr("font-size", labelFs)
            .style("fill", pc2Color);

        pcaPlot
            .append("g")
            .attr("class", "PC2 axis")
            .attr("transform", "translate(" + pad.left + "," + pad.top + ")")
            .call(pc2Axis)
            .selectAll("text")
            .attr("y", 0)
            .attr("x", -10)
            .style("fill", axisValColor);

        pcaPlot
            .append("path")
            .attr("d", lineFunction(verMidLineData))
            .attr("stroke", pc2Color)
            .attr("stroke-width", 1)
            .attr("fill", "none");

        pcaPlot
            .append("path")
            .attr("d", lineFunction(horMidLineData))
            .attr("stroke", pc1Color)
            .attr("stroke-width", 1)
            .attr("fill", "none");

        var grpColor = d3.scaleOrdinal(d3.schemeCategory10);
        pcaPlot
            .append("g")
            .selectAll("circle")
            .data(pc12)
            .enter()
            .append("circle")
            .style("fill", function (d) {
                return grpColor(trials.indexOf(d[0].trial));
            })
            .attr("r", 3)
            .attr("cx", function (d) {
                var xVal = d[0].pc1;
                if (xVal >= 0) {
                    return pad.left + width / 2 + pc1AxisScale(xVal);
                } else {
                    return pad.left + width / 2 - -1 * pc1AxisScale(xVal);
                }
            })
            .attr("cy", function (d) {
                var yVal = d[0].pc2;

                if (yVal >= 0) {
                    return pad.top + height / 2 - pc2AxisScale(yVal);
                } else {
                    return pad.top + height / 2 + -1 * pc2AxisScale(yVal);
                }
            })
            .on("mouseover", function (d) {
                d3.select(this).attr("r", 5).style("fill", axisValColor);
                pcaPlot
                    .append("text")
                    .attr("id", "dLabel")
                    .style("fill", axisValColor)
                    .text(d[0].name + "(" + d[0].pc1 + "," + d[0].pc2 + ")")
                    .attr("x", width + pad.left + rightNudge)
                    .attr("y", height / 2);
            })
            .on("mouseout", function (d) {
                d3.select(this)
                    .attr("r", 3)
                    .style("fill", function (d) {
                        return grpColor(trials.indexOf(d[0].trial));
                    });
                d3.selectAll("text#dLabel").remove();
            });

        pcaPlot
            .append("rect")
            .attr("transform", "translate(" + pad.left + "," + pad.top + ")")
            .attr("height", height)
            .attr("width", width + rightNudge)
            .attr("fill", "none")
            .attr("stroke", "#523CB5")
            .attr("stroke-width", 1)
            .attr("pointer-events", "none");

        var popName = "";
        if (plotData.list_name) {
            popName = plotData.list_name;
        }

        popName = popName
            ? popName + " (" + plotData.data_type + ")"
            : " (" + plotData.data_type + ")";
        var dld = "Download PCA " + popName + ": ";

        if (downloadLinks) {
            jQuery(pcaPlotDivId).append(
                `<p style="margin-left: 40px">${dld} ${downloadLinks}</p>`
            );
            var msgDivPrefix = pcaPlotDivId.replace(/pca_plot_|#/g, "");
            jQuery(pcaPlotDivId)
                .append(
                    `<div id="${msgDivPrefix}_pca_save_message" class="message"></div>`
                )
                .show();
        }

        if (trialsNames && Object.keys(trialsNames).length > 1) {
            var trialsIds = jQuery.uniqueSort(trials);
            trialsIds = jQuery.uniqueSort(trialsIds);

            var legendValues = [];
            var cnt = 0;
            var allTrialsNames = [];

            for (var tr in trialsNames) {
                allTrialsNames.push(trialsNames[tr]);
            }

            trialsIds.forEach(function (id) {
                var groupName = [];
                if (id.match(/-/)) {
                    var ids = id.split("-");

                    ids.forEach(function (id) {
                        groupName.push(trialsNames[id]);
                    });

                    groupName = "common to: " + groupName.join(", ");
                } else {
                    groupName = trialsNames[id];
                }
                legendValues.push([cnt, id, groupName]);
                cnt++;
            });

            var recLH = 20;
            var recLW = 20;
            var legendXOrig = pad.left + 10 + width;
            var legendYOrig = height * 0.25;

            var legend = pcaPlot
                .append("g")
                .attr("class", "cell")
                .attr(
                    "transform",
                    "translate(" + legendXOrig + "," + legendYOrig + ")"
                )
                .attr("height", 100)
                .attr("width", 100);

            legend = legend
                .selectAll("rect")
                .data(legendValues)
                .enter()
                .append("rect")
                .attr("x", function (d) {
                    return 1;
                })
                .attr("y", function (d) {
                    return 1 + d[0] * recLH + d[0] * 5;
                })
                .attr("width", recLH)
                .attr("height", recLW)
                .style("stroke", "black")
                .style("fill", function (d) {
                    return grpColor(trials.indexOf(d[1]));
                });

            var legendTxt = pcaPlot
                .append("g")
                .attr(
                    "transform",
                    "translate(" +
                    (legendXOrig + 30) +
                    "," +
                    (legendYOrig + 0.5 * recLW) +
                    ")"
                )
                .attr("id", "legendtext");

            legendTxt
                .selectAll("text")
                .data(legendValues)
                .enter()
                .append("text")
                .attr("fill", "#523CB5")
                .style("fill", "#523CB5")
                .attr("x", 1)
                .attr("y", function (d) {
                    return 1 + d[0] * recLH + d[0] * 5;
                })
                .text(function (d) {
                    return d[2];
                })
                .attr("dominant-baseline", "middle")
                .attr("text-anchor", "start");
        }
    },
    ////////
};
/////

jQuery(document).ready(function () {
    var url = location.pathname;
    var canvas = solGS.pca.canvas;

    if (url.match(/pca\/analysis/)) {
        var pcaArgs = solGS.pca.getPcaAnalysisArgs();

        var pcaPopId = pcaArgs.pca_pop_id;
        if (pcaPopId) {
            if (pcaArgs.data_structure && !pcaPopId.match(/list|dataset/)) {
                pcaArgs["pca_pop_id"] = pcaArgs.data_structure + "_" + pcaPopId;
            }

            pcaArgs["analysis_page"] = url;

            solGS.pca.checkCachedPca(pcaArgs).done(function (res) {
                if (res.scores) {
                    var plotData = solGS.pca.structurePlotData(res);
                    var downloadLinks = solGS.pca.pcaDownloadLinks(res);
                    solGS.pca.plotPca(plotData, downloadLinks);
                }
            });
        }
    }
});

jQuery(document).ready(function () {
    var canvas = solGS.pca.canvas;

    jQuery(canvas).on("click", "a", function (e) {
        var linkId = e.target.id;
        if (linkId.match(/download_pca_plot/)) {
            var pcaPlotId = linkId.replace(/download_/, "");

            if (pcaPlotId.match(/pca_plot_/)) {
                saveSvgAsPng(
                    document.getElementById("#" + pcaPlotId),
                    pcaPlotId + ".png",
                    { scale: 2 }
                );
            }
        }
    });
});

jQuery(document).ready(function () {
    var url = location.pathname;

    if (
        url.match(/solgs\/selection\/|solgs\/combined\/model\/\d+\/selection\//)
    ) {
        jQuery("#pca_data_type_select").html(
            '<option selected="genotype">Genotype</option>'
        );
    }
});

jQuery(document).ready(function () {
    jQuery("#pca_div").on("change", function (e) {
        var pcaHtmlElem = e.target.id;
        if (pcaHtmlElem.match(/pca_data_type_select/)) {
            var pcaPopId = pcaHtmlElem.replace(/pca_data_type_select_/, "");
            var runPcaBtnId = solGS.pca.getRunPcaId(pcaPopId);
            jQuery(`#${runPcaBtnId}`).html("Run PCA").show();
        }
    });
});

jQuery(document).ready(function () {
    jQuery("#pca_div").on("click", function (e) {
        var runPcaBtnId = e.target.id;
        if (runPcaBtnId.match(/run_pca/)) {
            var pcaArgs = solGS.pca.getPcaAnalysisArgs(runPcaBtnId);
            pcaPopId = pcaArgs.pca_pop_id;

            var canvas = solGS.pca.canvas;
            var pcaMsgDiv = solGS.pca.pcaMsgDiv;

            var pcaUrl = solGS.pca.generatePcaUrl(pcaPopId);
            pcaArgs["analysis_page"] = pcaUrl;

            solGS.pca
                .checkCachedPca(pcaArgs)
                .done(function (res) {
                    if (res.scores) {
                        var plotData = solGS.pca.structurePlotData(res);
                        var downloadLinks = solGS.pca.pcaDownloadLinks(res);
                        var pcaPlotLinkId = `#download_pca_plot_${res.file_id}`;

                        pcaResultDisplayed =
                            document.querySelector(pcaPlotLinkId);
                        if (!pcaResultDisplayed) {
                            solGS.pca.plotPca(plotData, downloadLinks);
                        }

                        jQuery(`#${runPcaBtnId}`).html("Done").show();

                        solGS.pca.cleanUpOnSuccess(pcaPopId);
                    } else {
                        var page = location.pathname;
                        var pcaUrl = solGS.pca.generatePcaUrl(
                            pcaArgs.pca_pop_id
                        );
                        pcaArgs["analysis_page"] = pcaUrl;

                        runPcaBtnId = `#${runPcaBtnId}`;

                        var title =
                            "<p>This analysis may take a long time. " +
                            "Do you want to submit the analysis and get an email when it completes?</p>";

                        var jobSubmit =
                            '<div id= "pca_submit">' + title + "</div>";

                        jQuery(jobSubmit).appendTo("body");

                        jQuery("#pca_submit").dialog({
                            height: "auto",
                            width: "auto",
                            modal: true,
                            title: "pca job submission",
                            buttons: {
                                OK: {
                                    text: "Yes",
                                    class: "btn btn-success",
                                    id: "queue_job",
                                    click: function () {
                                        jQuery(this).dialog("close");
                                        solGS.submitJob.checkUserLogin(
                                            pcaUrl,
                                            pcaArgs
                                        );
                                    },
                                },

                                No: {
                                    text: "No, I will wait till it completes.",
                                    class: "btn btn-warning",
                                    id: "no_queue",
                                    click: function () {
                                        jQuery(this).dialog("close");

                                        jQuery(runPcaBtnId)
                                            .html("Running...")
                                            .show();

                                        jQuery(
                                            `${canvas} .multi-spinner-container`
                                        ).show();
                                        jQuery(pcaMsgDiv)
                                            .html(
                                                "Running pca... please wait..."
                                            )
                                            .show();

                                        solGS.pca
                                            .runPcaAnalysis(pcaArgs)
                                            .done(function (res) {
                                                if (res.scores) {
                                                    var downloadLinks =
                                                        solGS.pca.pcaDownloadLinks(
                                                            res
                                                        );
                                                    var plotData =
                                                        solGS.pca.structurePlotData(
                                                            res
                                                        );
                                                    solGS.pca.plotPca(
                                                        plotData,
                                                        downloadLinks
                                                    );
                                                    jQuery(runPcaBtnId)
                                                        .html("Done")
                                                        .show();
                                                    solGS.pca.cleanUpOnSuccess(
                                                        pcaPopId
                                                    );
                                                } else {
                                                    var msg =
                                                        "There is no PCA output for this dataset.";
                                                    solGS.pca.feedBackOnFailure(
                                                        pcaPopId,
                                                        msg
                                                    );
                                                }
                                                jQuery(runPcaBtnId).show();
                                            })
                                            .fail(function (res) {
                                                var msg =
                                                    "Error occured running the PCA.";
                                                solGS.pca.feedBackOnFailure(
                                                    pcaPopId,
                                                    msg
                                                );
                                                jQuery(runPcaBtnId).show();
                                            });
                                    },
                                },

                                Cancel: {
                                    text: "Cancel",
                                    class: "btn btn-info",
                                    id: "cancel_queue_info",
                                    click: function () {
                                        jQuery(this).dialog("close");
                                    },
                                },
                            },
                        });
                        jQuery(jobSubmit).show();

                        jQuery("#queue_job").on("click", function (e) {
                            solGS.submitJob.checkUserLogin(page, args);
                        });

                        jQuery("#queue_no").on("click", function (e) {
                            solGS.pca
                                .runPcaAnalysis(pcaArgs)
                                .done(function (res) {
                                    if (res.scores) {
                                        var plotData =
                                            solGS.pca.structurePlotData(res);
                                        var downloadLinks =
                                            solGS.pca.pcaDownloadLinks(res);
                                        solGS.pca.plotPca(
                                            plotData,
                                            downloadLinks
                                        );
                                        jQuery(runPcaBtnId).html("Done").show();
                                        solGS.pca.cleanUpOnSuccess(pcaPopId);
                                    } else {
                                        var msg =
                                            "There is no PCA output for this dataset.";
                                        solGS.pca.feedBackOnFailure(
                                            pcaPopId,
                                            msg
                                        );
                                    }
                                })
                                .fail(function (res) {
                                    var msg = "Error occured running the PCA.";
                                    solGS.pca.feedBackOnFailure(pcaPopId, msg);
                                    jQuery(runPcaBtnId).show();
                                });
                        });
                    }
                })
                .fail(function () {
                    var msg = "Error occured checking for cached output.";
                    solGS.pca.feedBackOnFailure(pcaPopId, msg);
                    jQuery(runPcaBtnId).show();
                });
        }
    });
});

jQuery(document).ready(function () {
    if (location.pathname.match(/pca\/analysis/)) {
        pcaPopsDataDiv = solGS.pca.pcaPopsDataDiv;
        var tableId = "pca_pops_table";
        var pcaPopsTable = solGS.pca.createTable(tableId);
        jQuery(pcaPopsDataDiv).append(pcaPopsTable).show();

        var pcaPops = solGS.pca.getPcaPops();
        var pcaPopsRows = solGS.pca.getPcaPopsRows(pcaPops);

        solGS.pca.displayPcaPopsTable(tableId, pcaPopsRows);

        jQuery("#create_new_list_dataset").show();
    }
});

jQuery.fn.doesExist = function () {
    return jQuery(this).length > 0;
};
