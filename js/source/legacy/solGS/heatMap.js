/**
 * heatmap plotting using d3
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */


var solGS = solGS || function solGS() {};

solGS.heatmap = {

  plot: function (heatmapArgs) {
    var outputData = heatmapArgs.output_data;
    var inputData = heatmapArgs.input_data;
    var heatmapCanvasDiv = heatmapArgs.canvas;
    var heatmapPlotDivId = heatmapArgs.plot_div_id;
    var downloadLinks = heatmapArgs.download_links;
    var inputData = heatmapArgs.input_data;

    console.log("inputData:", inputData);
    if (heatmapCanvasDiv == null) {
      alert("The heatmap canvas div element is missing.");
    }

    if (jQuery(heatmapPlotDivId).length == 0) {
      var divId = heatmapPlotDivId.replace(/#/, "");
      jQuery(heatmapCanvasDiv).append("<div id=" + divId + "></div>");
    }

    if (heatmapCanvasDiv.match(/#/) == null) {
      heatmapCanvasDiv = "#" + heatmapCanvasDiv;
    }

    if (heatmapPlotDivId) {
      if (!heatmapPlotDivId.match(/#/)) {
        heatmapPlotDivId = "#" + heatmapPlotDivId;
      }
    } else {
      heatmapPlotDivId = "#heatmap_plot";
    }

    var heatmapPlotDivIdRaw = heatmapPlotDivId.replace(/#/, "");
    var scatterPlotDivId = heatmapPlotDivIdRaw + "_scatter_plot";
    var scatterPlotMsgDivId = heatmapPlotDivIdRaw + "_scatter_plot_msg";

    if (jQuery("#" + scatterPlotDivId).length == 0) {
      jQuery(heatmapPlotDivId).after("<div id=" + scatterPlotDivId + "></div>");
    }
    if (jQuery("#" + scatterPlotMsgDivId).length == 0) {
      jQuery("#" + scatterPlotDivId).before("<div id=" + scatterPlotMsgDivId + "></div>");
    }

    

    var parsedInputData = null;
    if (inputData) { 
        parsedInputData = JSON.parse(inputData);
    }

    var parsedOutputData = null;
    if (outputData) {
        parsedOutputData = JSON.parse(outputData);
    } else {
        alert(`The heatmap output data is missing: ${outputData}`);
        return;
    }

    var nLabels = parsedOutputData.labels.length;

    if (nLabels >= 100) {
      height = 600;
      width = 600;
      fontSize = "0.75em";
    } else {
      height = 500;
      width = 500;
    }

    if (nLabels < 20) {
      height = height * 0.5;
      width = width * 0.5;
    }

    var pad = { left: 150, top: 20, right: 250, bottom: 100 };
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;

    var nve = "#6A0888";
    var pve = "#86B404";
    var nral = "#98AFC7"; //blue gray
    var txtColor = "#523CB5";

    var fontSize = "0.95em";
    
    var corr = [];
    var coefs = [];

    var labels = parsedOutputData.labels;
    var values = parsedOutputData.values;
    var pvalues = parsedOutputData.pvalues;

    for (var i = 0; i < values.length; i++) {
      var rw = values[i];
      var rwPvalues;
      if (pvalues) {
        rwPvalues = pvalues[i];
      }

      for (var j = 0; j < nLabels; j++) {
        var clNm = labels[j];
        var rwVl = rw[clNm];

        var rwPV;
        if (pvalues) {
          rwPV = rwPvalues[clNm];
        } else {
          rwPV = "NA";
        }
        if (!rwVl && rwVl !== 0) {
          rwVl = "NA";
        }

        if (rwVl != "NA") {
          coefs.push(rwVl);
          rwVl = d3.format(".2f")(rwVl);
        }

        corr.push({ row: i, col: j, value: rwVl, pvalue: rwPV });
      }
    }

    var rmax = d3.max(coefs);
    var rmin = d3.min(coefs);
    var coefRange = [];
    var coefDom = [];

    if (rmin >= 0 && rmax > 0) {
      rmax = rmax;
      coefDom = [0, rmax];
      coefRange = ["white", pve];
    } else if (rmin < 0 && rmax > 0) {
      if (-rmin > rmax) {
        rmax = -rmin;
      }
      coefDom = [-rmax, 0,  rmax];
      coefRange = [nve, "white", pve];
    } else if (rmin <= 0 && rmax < 0) {
      coefDom = [rmin, 0];
      coefRange = [nve, "white"];
    }
    
    var corZscale = d3.scaleLinear().domain(coefDom).range(coefRange);
    var xAxisScale = d3.scaleBand()
		.range([0, width])	
		.domain(labels)
		.padding(0.00);

    var yAxisScale = d3.scaleBand()
		.range([height, 0])
		.domain(labels)
		.padding(0.00);
    
    var xAxis = d3.axisBottom(xAxisScale).tickSizeOuter(0).tickPadding(5);
    var yAxis  = d3.axisLeft(yAxisScale).tickSizeOuter(0);

    var svg = d3
      .select(heatmapPlotDivId)
      .insert("svg", ":first-child")
      .attr("height", totalH)
      .attr("width", totalW);
     
    var  corrplot = svg.append("g")
      .attr("id", heatmapPlotDivId)
      .attr("transform", "translate(0, 0)");

    corrplot
      .append("g")
      .attr("class", "y_axis")
      .attr("transform", `translate(${pad.left}, ${pad.top})`)
      .call(yAxis)
      .selectAll("text")
      .attr("x", -10)
      .attr("y", 0)
      .attr("dy", ".3em")
      .attr("fill", txtColor)
      .style("font-size", fontSize);

    corrplot
      .append("g")
      .attr("class", "x_axis")
      .attr("transform", `translate(${pad.left}, ${pad.top + height})`)
      .call(xAxis)
      .selectAll("text")
      .style("text-anchor", "end")
      .attr("x", "-10")
      .attr("y", 0)
      .attr("dy", ".3em")
      .attr("transform", "rotate(-90)")
      .attr("fill", txtColor)
      .style("font-size", fontSize);
      
    corrplot
      .selectAll()
      .data(corr)
      .attr("transform", `translate(${pad.left}, ${pad.top})`)
      .enter()
      .append("rect")
      .attr("class", "cell")
      .attr("x", function (d) {
        return pad.left +  xAxisScale(labels[d.col]);
      })
      .attr("y", function (d) {
        return pad.top + yAxisScale(labels[d.row]);
      })
      .attr("width", xAxisScale.bandwidth())
      .attr("height", yAxisScale.bandwidth())
      .style("stroke",  function (d) {
        if (d.value == "NA") {
          return "white";
        } else {
        return txtColor;
        }})
      .style("stroke-opacity", 0.2)
      .attr("fill", function (d) {
        if (d.value == "NA") {
          return "white";
        } else {
        return corZscale(d.value);
        }})
      .attr("stroke", "white")
      .attr("stroke-width", 1)
      .on("mouseover", function (d) {
        if (d.value != "NA") {
          d3.select(this).attr("stroke", "green");
          var rowLabel = labels[d.row];
          var colLabel = labels[d.col];
        
          corrplot
            .append("text")
            .attr("id", "corrtext")
            .html(function () {
              if (d.pvalue != "NA") {
                var pv;
                if (rowLabel === colLabel) {
                  pv = 0.00;
                } else {
                  pv = d.pvalue;
                }
                return `${rowLabel} vs. ${colLabel}:  
              r=${d.value}, p=${d3.format(".2f")(pv)}`;
              } else {
                return `${rowLabel} vs. ${colLabel}:  
                ${d.value}`;
              }
            })
            .style("fill", function () {
              if (d.value > 0) {
                return pve;
              } else if (d.value == 0) {
                return nral;
              } else if (d.value < 0) {
                return nve;
              }
            })
            .attr("x", pad.left + 40)
            .attr("y", pad.top - 10)
            .attr("font-weight", "bold")
            .attr("dominant-baseline", "middle")
            .attr("text-anchor", "middle");

          if (parsedInputData) {
            jQuery("#" + scatterPlotMsgDivId)
              .html("Scatter plot: " + rowLabel + " vs. " + colLabel)
              .show();

            var xData = [];
            var yData = [];

            
            jQuery.each(parsedInputData, function (sampleName, colValues) {
              if (!colValues) {
                return true;
              }
              var xVal = colValues[colLabel];
              var yVal = colValues[rowLabel];
        
              if (xVal === "NA" || yVal === "NA") {
                return true;
              }
            
              xData.push([sampleName, xVal]);
              yData.push([sampleName, yVal]);
            });

    
            var corrValues = {row: rowLabel, col: colLabel, coef: d.value, pvalue: d.pvalue};
            jQuery("#" + scatterPlotDivId).empty();
            solGS.scatterPlot.plotRegression({
              x_data: xData,
              y_data: yData,
              x_label: colLabel,
              y_label: rowLabel,
              plot_div_id: scatterPlotDivId,
              corr_values: corrValues,
              canvas: heatmapCanvasDiv,
              axis_mode: 2,
            });
          } else {
            console.log("No input data available for scatter plot.");
          }
        }
      })
      .on("mouseout", function () {
        d3.selectAll("text.corrlabel").remove();
        d3.selectAll("text#corrtext").remove();
        d3.select(this).attr("stroke", "white");
        jQuery("#" + scatterPlotMsgDivId).empty();
      });

    corrplot
      .append("rect")
      .attr("transform", `translate(${pad.left}, ${pad.top})`)
      .attr("height", height)
      .attr("width", width)
      .attr("fill", "none")
      .attr("stroke", txtColor)
      .attr("stroke-width", 1)
      .attr("pointer-events", "none");

    var bins = d3.ticks(d3.min(coefs), d3.max(coefs), 10)
    var legendValues = [];

    for (var i = 0; i < bins.length; i++) {
      legendValues.push([i, bins[i]])
    }

    if (heatmapCanvasDiv.match(/kinship/)) {
      legendValues.push(
        [legendValues.length + 1, "Diag: inbreeding coefficients"],
        [legendValues.length + 2, "Off-diag: kinship coefficients"]
      );
    }

    var legendX = pad.left + width + 30;
    var legendY = pad.top;

    var legend = corrplot
      .append("g")
      .attr("class", "cell")
      .attr(
        "transform",
        `translate(${legendX}, ${legendY})`
      )
    
    var recLH = 20;
    var recLW = 20;

    legend = legend
      .selectAll("rect")
      .data(legendValues)
      .enter()
      .append("rect")
      .attr("x", 1)
      .attr("y", function (d) {
        return d[0] * recLH;
      })
      .attr("width", recLH)
      .attr("height", recLW)
      .style("stroke", "White")
      .attr("fill", function (d) {
        if (d == "NA") {
          return "white";
         } else {
          return corZscale(d[1]);
        }
      });

    var legendTxt = corrplot
      .append("g")
      .attr(
        "transform",
        `translate(${legendX + 30}, ${legendY + 0.5 * recLH})`
      )
      .attr("id", "legendtext");

    legendTxt
      .selectAll("text")
      .data(legendValues)
      .enter()
      .append("text")
      .attr("fill", txtColor)
      .style("fill", txtColor)
      .attr("x", 1)
      .attr("y", function (d) {
        return d[0] * recLH;
      })
      .text(function (d) { return d[1];
      })
      .attr("dominant-baseline", "middle")
      .attr("text-anchor", "start");

    if (downloadLinks) {
      if (!heatmapPlotDivId.match("#")) {
        heatmapPlotDivId = "#" + heatmapPlotDivId;
      }
      jQuery(heatmapPlotDivId).append('<p style="margin-left: 40px">' + downloadLinks + "</p>");
    }
  },

  ///////
};
