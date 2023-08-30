/**
 * heatmap plotting using d3
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.heatmap = {
  plot: function (data, heatmapCanvasDiv, heatmapPlotDivId, downloadLinks) {
    if (heatmapCanvasDiv == null) {
      alert("The div element where the heatmap to draw is missing.");
    }

    if (jQuery(heatmapPlotDivId).length == 0) {
      var divId = heatmapPlotDivId.replace(/#/, "");
      jQuery(heatmapCanvasDiv).append("<div id=" + divId + "></div>");
    }

    data = JSON.parse(data);

    var labels = data.labels;
    var values = data.values;
    var pvalues = data.pvalues;
    var nLabels = labels.length;

    var corr = [];
    var coefs = [];

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

        corr.push({ row: i, col: j, value: rwVl, pvalue: rwPV });

        if (rwVl != "NA") {
          coefs.push(rwVl);
        }
      }
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

    var fs = 10;

    if (nLabels >= 100) {
      height = 600;
      width = 600;
      fs = 10 * 0.85;
    } else {
      height = 500;
      width = 500;
      fs = 10 * 1.2;
    }

    if (nLabels < 20) {
      height = height * 0.5;
      width = width * 0.5;
      fs = 10 * 1.3;
    }

    fs = fs + "px";

    var pad = { left: 150, top: 20, right: 250, bottom: 150 };
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;

    var nve = "#6A0888";
    var pve = "#86B404";
    var nral = "#98AFC7"; //blue gray

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
      coefDom = [-rmax, 0, rmax];
      coefRange = [nve, "white", pve];
    } else if (rmin <= 0 && rmax < 0) {
      coefDom = [rmin, 0];
      coefRange = [nve, "white"];
    }

    var corXscale = d3.scale.ordinal().domain(d3.range(nLabels)).rangeBands([0, width]);
    var corYscale = d3.scale.ordinal().domain(d3.range(nLabels)).rangeBands([height, 0]);
    var corZscale = d3.scale.linear().domain(coefDom).range(coefRange);

    var xAxisScale = d3.scale.ordinal().domain(labels).rangeBands([0, width]);

    var yAxisScale = d3.scale.ordinal().domain(labels).rangeRoundBands([height, 0]);

    var svg = d3
      .select(heatmapPlotDivId)
      .insert("svg", ":first-child")
      .attr("height", totalH)
      .attr("width", totalW);

    var xAxis = d3.svg.axis().scale(xAxisScale).orient("bottom");

    var yAxis = d3.svg.axis().scale(yAxisScale).orient("left");

    var corrplot = svg
      .append("g")
      .attr("id", heatmapPlotDivId)
      .attr("transform", "translate(0, 0)");

    corrplot
      .append("g")
      .attr("class", "y axis")
      .attr("transform", "translate(" + pad.left + "," + pad.top + ")")
      .call(yAxis)
      .selectAll("text")
      .attr("x", -10)
      .attr("y", 0)
      .attr("dy", ".1em")
      .attr("fill", "#523CB5")
      .style({ fill: "#523CB5", "font-size": fs });

    corrplot
      .append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(" + pad.left + "," + (pad.top + height) + ")")
      .call(xAxis)
      .selectAll("text")
      .attr("x", 10)
      .attr("y", 0)
      .attr("dy", ".1em")
      .attr("transform", "rotate(90)")
      .attr("fill", "#523CB5")
      .style({ "text-anchor": "start", fill: "#523CB5", "font-size": fs });

    corrplot
      .selectAll()
      .data(corr)
      .attr("transform", "translate(" + pad.left + "," + pad.top + ")")
      .enter()
      .append("rect")
      .attr("class", "cell")
      .attr("x", function (d) {
        return pad.left + corXscale(d.col);
      })
      .attr("y", function (d) {
        return pad.top + corYscale(d.row);
      })
      .attr("width", corXscale.rangeBand())
      .attr("height", corYscale.rangeBand())
      .attr("fill", function (d) {
        if (d.value == "NA") {
          return "white";
        } else if (d.value == 0) {
          return nral;
        } else {
          return corZscale(d.value);
        }
      })
      .attr("stroke", "white")
      .attr("stroke-width", 1)
      .on("mouseover", function (d) {
        if (d.value != "NA") {
          d3.select(this).attr("stroke", "green");
          corrplot
            .append("text")
            .attr("id", "corrtext")
            .text(function () {
              if (d.pvalue != "NA") {
                return `[${labels[d.row]} vs. ${labels[d.col]}:  
							${d3.format(".3f")(d.value)}, 
							p-value: ${d3.format(".3f")(d.pvalue)}]`;
              } else {
                return `[${labels[d.row]} vs. ${labels[d.col]}:  
								${d3.format(".3f")(d.value)}]`;
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
            .attr("x", function () {
              if (nLabels < 20) {
                return pad.left + width;
              } else {
                return pad.left + width * 0.5;
              }
            })
            .attr("y", pad.top + height * 0.9)
            .attr("font-weight", "bold")
            .attr("dominant-baseline", "middle")
            .attr("text-anchor", "middle");
        }
      })
      .on("mouseout", function () {
        d3.selectAll("text.corrlabel").remove();
        d3.selectAll("text#corrtext").remove();
        d3.select(this).attr("stroke", "white");
      });

    corrplot
      .append("rect")
      .attr("transform", "translate(" + pad.left + "," + pad.top + ")")
      .attr("height", height)
      .attr("width", width)
      .attr("fill", "none")
      .attr("stroke", "#523CB5")
      .attr("stroke-width", 1)
      .attr("pointer-events", "none");

    var legendValues = [];

    if (d3.min(coefs) >= 0 && d3.max(coefs) > 0) {
      legendValues = [
        [0, 0],
        [1, d3.max(coefs)],
      ];
    } else if (d3.min(coefs) < 0 && d3.max(coefs) < 0) {
      legendValues = [
        [0, d3.min(coefs)],
        [1, 0],
        [2, 1],
      ];
    } else {
      legendValues = [
        [0, d3.min(coefs)],
        [1, 0],
        [2, d3.max(coefs)],
      ];
    }

    if (heatmapCanvasDiv.match(/kinship/)) {
      legendValues.push(
        [3, "Diagonals: inbreeding coefficients"],
        [4, "Off-diagonals: kinship coefficients"]
      );
    }
    var legend = corrplot
      .append("g")
      .attr("class", "cell")
      .attr(
        "transform",
        "translate(" + (pad.left + width + 10) + "," + (pad.top + height * 0.25) + ")"
      )
      .attr("height", 100)
      .attr("width", 100);

    var recLH = 20;
    var recLW = 20;

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
      .attr("fill", function (d) {
        if (d == "NA") {
          return "white";
        } else if (d[1] == 0) {
          return nral;
        } else {
          return corZscale(d[1]);
        }
      });

    var legendTxt = corrplot
      .append("g")
      .attr(
        "transform",
        "translate(" + (pad.left + width + 40) + "," + (pad.top + height * 0.25 + 0.5 * recLW) + ")"
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
        if (d[1] > 0) {
          return "> 0";
        } else if (d[1] < 0) {
          return "< 0";
        } else if (d[1] == 0) {
          return "0";
        } else {
          return d[1];
        }
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
